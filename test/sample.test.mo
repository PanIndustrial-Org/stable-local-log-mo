import {test; expect; testsys;} "mo:test/async";


import Local_log "../src"


await test("local_log test", func() : async() {

  

  let result = Local_log.test();
  expect.nat(result).equal(1); // Assuming the test method returns 0 for success


});