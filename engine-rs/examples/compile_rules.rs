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

#[derive(Serialize)]
struct DnrRule {
    id: u32,
    priority: u32,
    action: DnrAction,
    condition: DnrCondition,
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

    let lists = ["easylist.txt", "easyprivacy.txt"];
    let mut filter_set = FilterSet::new(true); // debug=true is required for into_content_blocking
    for name in &lists {
        let path = root.join("filterlists").join(name);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("read {}: {}", path.display(), e));
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

    eprintln!(
        "wrote {} rules ({} skipped: cookies/cosmetic/https) -> {}",
        dnr_rules.len(),
        skipped,
        out.display(),
    );
}
