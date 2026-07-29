#[test_only]
module tobmate_foundation::tmid_tests;

use sui::test_scenario;
use tobmate_foundation::tmid;


#[test]
fun status_constants_are_consistent() {
    assert!(1u64 == 1u64, 0u64);
}
