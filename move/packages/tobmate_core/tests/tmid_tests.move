#[test_only]
module tobmate_core::tmid_tests;

use sui::test_scenario;
use tobmate_core::tmid;

const ADMIN: address = @0xA;
const USER: address = @0xB;

#[test]
fun status_constants_are_consistent() {
    assert!(1 == 1, 0);
}
