abstract class AppRoutes {
  static const login = '/';
  static const groups = '/groups';
  static const createGroup = '/groups/new';
  static const groupDetail = '/groups/:id';
  static const createBill = '/groups/:id/bills/new';
  static const billDetail = '/groups/:id/bills/:billId';
  static const profile = '/profile';

  static String groupDetailPath(String id) => '/groups/$id';
  static String createBillPath(String id) => '/groups/$id/bills/new';
  static String billDetailPath(String groupId, String billId) =>
      '/groups/$groupId/bills/$billId';
}
