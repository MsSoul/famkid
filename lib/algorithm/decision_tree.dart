// filename: ../algorithm/decision_tree.dart
// filename: ../algorithm/decision_tree.dart

class DecisionTree {
  final double theta1;
  final double theta2;

  DecisionTree({required this.theta1, required this.theta2});

  bool isAllowed(double x1, double x2) {
    String decision = decide(x1, x2);
    return decision == 'Allow';
  }

  String decide(double x1, double x2) {
    if (x1 < theta1) {
      return 'Allow';
    } else if (x1 >= theta1 && x2 < theta2) {
      return 'Block';
    } else if (x1 >= theta1 && x2 >= theta2) {
      return 'Allow';
    }
    return 'Undefined'; // Default case, should not happen with the given conditions
  }
}


/*
class DecisionTree {
  final double theta1;
  final double theta2;

  DecisionTree({required this.theta1, required this.theta2});

  String decide(double x1, double x2) {
    if (x1 < theta1) {
      return 'Allow';
    } else if (x1 >= theta1 && x2 < theta2) {
      return 'Block';
    } else if (x1 >= theta1 && x2 >= theta2) {
      return 'Allow';
    }
    return 'Undefined'; // Default case, should not happen with the given conditions
  }
}

/*
•The DecisionTree class encapsulates the decision logic.
•The DecisionTreeScreen widget demonstrates how to use this class.
•The decide method in the DecisionTree class implements the decision logic based on the thresholds theta1 and theta2.
•The main function runs the app, displaying the decision based on the example input values x1 and x2.
*/

*/