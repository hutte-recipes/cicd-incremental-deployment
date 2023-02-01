@isTest
private class Test_Greeter2 {
  @isTest
  static void greet() {
    System.assertEquals(Greeter2.greet('John'), 'Hello John');
  }
}
