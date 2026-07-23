#[test_only]
module tobmate_core::asset_collection_tests;

use tobmate_core::asset_collection;

const E_WRONG_ASSET_CLASS: u64 = 1;

#[test]
fun gold_asset_class_is_correct() {
    assert!(
        asset_collection::asset_gold() == 1,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun silver_asset_class_is_correct() {
    assert!(
        asset_collection::asset_silver() == 2,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun platinum_asset_class_is_correct() {
    assert!(
        asset_collection::asset_platinum() == 3,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun diamond_asset_class_is_correct() {
    assert!(
        asset_collection::asset_diamond() == 10,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun ruby_asset_class_is_correct() {
    assert!(
        asset_collection::asset_ruby() == 11,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun sapphire_asset_class_is_correct() {
    assert!(
        asset_collection::asset_sapphire() == 12,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun emerald_asset_class_is_correct() {
    assert!(
        asset_collection::asset_emerald() == 13,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun jewelry_asset_class_is_correct() {
    assert!(
        asset_collection::asset_jewelry() == 20,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun art_asset_class_is_correct() {
    assert!(
        asset_collection::asset_art() == 30,
        E_WRONG_ASSET_CLASS,
    );
}

#[test]
fun collectible_asset_class_is_correct() {
    assert!(
        asset_collection::asset_collectible() == 40,
        E_WRONG_ASSET_CLASS,
    );
}
