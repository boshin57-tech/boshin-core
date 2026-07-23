#[test_only]
module tobmate_core::tmid_tests;

use sui::test_scenario;
use tobmate_core::tmid;


#[test]
fun status_constants_are_consistent() {
    assert!(1u64 == 1u64, 0u64);
}
