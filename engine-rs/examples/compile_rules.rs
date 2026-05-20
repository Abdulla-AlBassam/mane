//! Compile EasyList + EasyPrivacy into a declarativeNetRequest JSON file the
//! Safari and Chrome extensions load directly. Runs once at build time, not
//! at runtime in the browser.
//!
//! Pipeline:
//!   filterlists/easylist.txt + easyprivacy.txt
//!     -> adblock::FilterSet (parsed)
//!     -> Vec<CbRule>  (Safari Content Blocker format, via Brave's converter)
//!     -> Vec<DnrRule> (declarativeNetRequest format, mechanical mapping)
//!     -> safari-ext/rules.json
//!
//! Run with: `cargo run --example compile_rules --release`

use adblock::content_blocking::{CbLoadType, CbResourceType, CbRule, CbType};
use adblock::lists::{FilterSet, ParseOptions};
use serde::Serialize;
use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize)]
struct DnrRule {
    id: u32,
    priority: u32,
    action: DnrAction,
    condition: DnrCondition,
}

#[derive(Serialize)]
struct FilterListMeta {
    name: &'static str,
    filename: &'static str,
    #[serde(rename = "updatedAtUnix")]
    updated_at_unix: u64,
    #[serde(rename = "byteCount")]
    byte_count: u64,
}

#[derive(Serialize)]
struct FilterListsManifest {
    #[serde(rename = "ruleCount")]
    rule_count: usize,
    skipped: usize,
    #[serde(rename = "compiledAtUnix")]
    compiled_at_unix: u64,
    lists: Vec<FilterListMeta>,
}

#[derive(Serialize)]
struct DnrAction {
    #[serde(rename = "type")]
    typ: &'static str,
}

#[derive(Serialize, Default)]
#[serde(rename_all = "camelCase")]
struct DnrCondition {
    #[serde(skip_serializing_if = "Option::is_none")]
    regex_filter: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    resource_types: Vec<&'static str>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    initiator_domains: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    excluded_initiator_domains: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    domain_type: Option<&'static str>,
}

fn map_resource_types(rt: &Option<HashSet<CbResourceType>>) -> Vec<&'static str> {
    let Some(types) = rt else {
        return Vec::new();
    };
    let mut out: BTreeSet<&'static str> = BTreeSet::new();
    for t in types {
        match t {
            CbResourceType::Document => {
                out.insert("main_frame");
                out.insert("sub_frame");
            }
            CbResourceType::Image => {
                out.insert("image");
            }
            CbResourceType::StyleSheet => {
                out.insert("stylesheet");
            }
            CbResourceType::Script => {
                out.insert("script");
            }
            CbResourceType::Font => {
                out.insert("font");
            }
            CbResourceType::Raw => {
                out.insert("xmlhttprequest");
                out.insert("ping");
                out.insert("csp_report");
                out.insert("other");
            }
            CbResourceType::SvgDocument => {
                out.insert("image");
            }
            CbResourceType::Media => {
                out.insert("media");
            }
            CbResourceType::Popup => {}
        }
    }
    out.into_iter().collect()
}

fn clean_domain(d: String) -> String {
    d.trim_start_matches('*')
        .trim_start_matches('.')
        .to_string()
}

fn translate(cb: CbRule, id: u32) -> Option<DnrRule> {
    let action_type = match cb.action.typ {
        CbType::Block => "block",
        CbType::IgnorePreviousRules => "allow",
        CbType::BlockCookies | CbType::CssDisplayNone | CbType::MakeHttps => return None,
    };

    let mut condition = DnrCondition {
        regex_filter: Some(cb.trigger.url_filter),
        resource_types: map_resource_types(&cb.trigger.resource_type),
        ..DnrCondition::default()
    };

    if let Some(if_d) = cb.trigger.if_domain {
        condition.initiator_domains = if_d
            .into_iter()
            .map(clean_domain)
            .filter(|d| !d.is_empty())
            .collect();
    }
    if let Some(un_d) = cb.trigger.unless_domain {
        condition.excluded_initiator_domains = un_d
            .into_iter()
            .map(clean_domain)
            .filter(|d| !d.is_empty())
            .collect();
    }
    if let Some(lt) = cb.trigger.load_type.first() {
        condition.domain_type = Some(match lt {
            CbLoadType::FirstParty => "firstParty",
            CbLoadType::ThirdParty => "thirdParty",
        });
    }

    Some(DnrRule {
        id,
        priority: if action_type == "allow" { 2 } else { 1 },
        action: DnrAction { typ: action_type },
        condition,
    })
}

fn main() {
    let root: PathBuf = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf();

    let lists = [
        ("EasyList", "easylist.txt"),
        ("EasyPrivacy", "easyprivacy.txt"),
        ("Fanboy's Annoyance", "fanboy-annoyance.txt"),
        ("Peter Lowe's List", "peter-lowe.txt"),
    ];
    let mut filter_set = FilterSet::new(true); // debug=true is required for into_content_blocking
    let mut list_meta: Vec<FilterListMeta> = Vec::with_capacity(lists.len());
    for (name, filename) in &lists {
        let path = root.join("filterlists").join(filename);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("read {}: {}", path.display(), e));
        let metadata = fs::metadata(&path)
            .unwrap_or_else(|e| panic!("stat {}: {}", path.display(), e));
        let updated_at_unix = metadata
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        list_meta.push(FilterListMeta {
            name,
            filename,
            updated_at_unix,
            byte_count: metadata.len(),
        });
        filter_set.add_filter_list(&text, ParseOptions::default());
    }

    let (cb_rules, _used) = filter_set
        .into_content_blocking()
        .expect("into_content_blocking requires debug=true on FilterSet");

    let mut next_id: u32 = 1;
    let mut dnr_rules: Vec<DnrRule> = Vec::with_capacity(cb_rules.len());
    let mut skipped = 0usize;
    for cb in cb_rules {
        if let Some(r) = translate(cb, next_id) {
            dnr_rules.push(r);
            next_id += 1;
        } else {
            skipped += 1;
        }
    }

    let out = root.join("safari-ext").join("rules.json");
    let json = serde_json::to_string(&dnr_rules).expect("serialize rules.json");
    fs::write(&out, json).unwrap_or_else(|e| panic!("write {}: {}", out.display(), e));

    let compiled_at_unix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let manifest = FilterListsManifest {
        rule_count: dnr_rules.len(),
        skipped,
        compiled_at_unix,
        lists: list_meta,
    };
    let manifest_out = root.join("safari-ext").join("filterlists-meta.json");
    let manifest_json =
        serde_json::to_string_pretty(&manifest).expect("serialize filterlists-meta.json");
    fs::write(&manifest_out, manifest_json)
        .unwrap_or_else(|e| panic!("write {}: {}", manifest_out.display(), e));

    eprintln!(
        "wrote {} rules ({} skipped: cookies/cosmetic/https) -> {}",
        dnr_rules.len(),
        skipped,
        out.display(),
    );
    eprintln!("wrote filter list manifest -> {}", manifest_out.display());
}
