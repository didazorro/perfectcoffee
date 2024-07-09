import 'dart:convert';

import 'package:stackfood_multivendor/common/models/response_model.dart';
import 'package:stackfood_multivendor/api/api_client.dart';
import 'package:stackfood_multivendor/features/address/domain/models/address_model.dart';
import 'package:stackfood_multivendor/features/auth/domain/models/signup_body_model.dart';
import 'package:stackfood_multivendor/features/auth/domain/models/social_log_in_body_model.dart';
import 'package:stackfood_multivendor/features/auth/domain/reposotories/auth_repo_interface.dart';
import 'package:stackfood_multivendor/helper/address_helper.dart';
import 'package:stackfood_multivendor/util/app_constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
import 'package:http/http.dart' as http;

class AuthRepo implements AuthRepoInterface<SignUpBodyModel> {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  AuthRepo({required this.sharedPreferences, required this.apiClient});

  @override
  Future<bool> saveUserToken(String token, {bool alreadyInApp = false}) async {
    apiClient.token = token;
    if (alreadyInApp && sharedPreferences.getString(AppConstants.userAddress) != null) {
      AddressModel? addressModel = AddressModel.fromJson(jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!));
      apiClient.updateHeader(
        token,
        addressModel.zoneIds,
        sharedPreferences.getString(AppConstants.languageCode),
        addressModel.latitude,
        addressModel.longitude,
      );
    } else {
      apiClient.updateHeader(token, null, sharedPreferences.getString(AppConstants.languageCode), null, null);
    }

    return await sharedPreferences.setString(AppConstants.token, token);
  }

  @override
  Future<Response> updateToken({String notificationDeviceToken = ''}) async {
    String? deviceToken;
    if (notificationDeviceToken.isEmpty) {
      if (GetPlatform.isIOS && !GetPlatform.isWeb) {
        FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          deviceToken = await _saveDeviceToken();
        }
      } else {
        deviceToken = await _saveDeviceToken();
      }
      if (!GetPlatform.isWeb) {
        FirebaseMessaging.instance.subscribeToTopic(AppConstants.topic);
      }
    }
    return await apiClient.postData(
        AppConstants.tokenUri, {"_method": "put", "cm_firebase_token": notificationDeviceToken.isNotEmpty ? notificationDeviceToken : deviceToken});
  }

  Future<String?> _saveDeviceToken() async {
    String? deviceToken = '@';
    if (!GetPlatform.isWeb) {
      try {
        deviceToken = (await FirebaseMessaging.instance.getToken())!;
        print("---------DeviceToekn");
        print(deviceToken);
      } catch (_) {}
    }
    if (deviceToken != null) {
      debugPrint('--------Device Token---------- $deviceToken');
    }
    getAccessToken();

    return deviceToken;
  }

  // Code added 30 june 2024 for getting firebase serverkey

  static Future<String> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "perfectcoffee-75e3a",
      "private_key_id": "1dafcb647bb6fce57b40154f1989745baf5a8c81",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDFrQPABBnRFuCc\nUAz0vhKM2hMBRVLdgAoUymW6sAKOVwr3J4poX/7oJI6mULNvjMIN8BH3/dQbwGK7\nzlQMvnVe+SupT2FtKKK2ij5D1dGH3/2Da+bxUffNOcx8gyVdR7dOAApRDzMrXFKu\nl8xzG7sdmy5FrVqWK3++fLMZnL7wZxOluooEQB36GguvxWCyXQIdBaf8Bpkvwmt3\nosFktDTkbMWPnj9CNIMosch5NTUdIzEr8w2Xm5F4ok8/XmW7O15LpEHYB5KMlfLv\n8ckl1qHkfsGRnjyChnazYCqU1vLTCxK6Ze34YkPSiI4zBIdFV0vD49po7JitaDrS\nSgP9xOQDAgMBAAECggEANxa4bNK3vyV5AxbsBWjTEp3Tng8LwN7l8FVXdGeIztJD\nJA3I7L2T9G37sy3aU8QOcIPu/gWnDvTWjzA5DDQn0YfvOwf8RseEUQrFv3HfKtap\nd+6iNa56OJ9a9Xg2+X/6/anVNjHeOL9J644yVAHua5nLk290R1VoDFYEM6cTLzuM\nPHw45Lv5/AIYwTUqwTAHJkyh0ALuzN5L/TPif7NfsT/36VVbIgL3uNCEVH5YrLbQ\nBjZqcffbT4pet0zBlHYeejtHn8kQQnATvyuuzqBgZtQjFYNBEKmT2pdowmgf7LPm\nJsU5/HsV/73HBT3D0LweCJhFB5EkQMrHugABgSw7AQKBgQD/rPCTy0xsMf9r32oP\nO1sH++FJ92WCeiyRe3ZlQFGtGiTKr8izajXG6KCSJbfVmLy/iMz+XRpHuRkhtbBW\n2WDpaj5kIJDQUZcUByp9b2HT9yqeN79Wjdlb5uQf1WoF9VUnfl4z2sJOPjS4OHKZ\nZKqxUa+AUs6D96Rhgyywd7AQkQKBgQDF7TuW5VgvCNwZbpsRAukw37cl4uw8DW0i\nmSlWJhjBXJ6kg3mI0zMwerWjsqc9DKYuZiuLd3kj979AIOYcxQoSbDGyugiH+/jX\nS3azSph581H7EncVOJeDBi/3/v4a4pdEOxX1EuauORw8M7Dc93AuSKB7R7S7/E9y\nhy9UoOm1UwKBgHBzB3x5NauAce5n3KXGXUstpPB7NtIkGeYCfxgZKdMQZI4gsgz2\n8aACQF0G6cuv2ZQD/uUA3cYdysfguSX5hX4jlD1FdWup9uCAJlf03Pn1A3GC40yW\nJrsc2ciGfJMSS9mK4rO7yynOgjFj4kNE2y4R1zaBNQMlr86TetxCR9WBAoGAQRg+\nyufu0rlFOhAIa9XbP7m0EH/LVgzMYd6hm7W32pBNlKmw5PEhGsagyo/NNOTeGtB7\nbckDTHMEsWCgjcG4CEsRJUjN2XtjYdtt1JWqBCGkSsDN7WrJWcxFJnj0tX7kZQpR\ntGJc/9vEj4AooOO4P2CfdywkItdegbo4NMsfUgUCgYBoTyH93Ut0FPNnHFmqxdJk\nl4GKAw7JyA7XZwsThmecDh6W6PEanOMxZcv6ol+d7cFjDd4A4nzOWE54Az4FIXZo\nCFFNtAD32Sec+M19NTATCT+IHPQiL/h3maXvgX5aeKLANO/Ap+JjJ4oOzzREVr0H\nfTsY5PkldqpoYWrT7q9PIg==\n-----END PRIVATE KEY-----\n",
      "client_email": "perfect-coffee-messageing@perfectcoffee-75e3a.iam.gserviceaccount.com",
      "client_id": "108345069658316839474",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/perfect-coffee-messageing%40perfectcoffee-75e3a.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging"
    ];

    http.Client client = await auth.clientViaServiceAccount(auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);

    auth.AccessCredentials credentials =
        await auth.obtainAccessCredentialsViaServiceAccount(auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes, client);

    client.close();
    print("-------------ServerKey----------------  ${credentials.accessToken.data}");
    return credentials.accessToken.data;
  }

  @override
  Future<Response> registration(SignUpBodyModel signUpModel) async {
    return await apiClient.postData(AppConstants.registerUri, signUpModel.toJson(), handleError: false);
  }

  @override
  Future<Response> login({String? phone, String? password}) async {
    String guestId = getGuestId();
    Map<String, String> data = {
      "phone": phone!,
      "password": password!,
    };
    if (guestId.isNotEmpty) {
      data.addAll({"guest_id": guestId});
    }
    return await apiClient.postData(AppConstants.loginUri, data, handleError: false);
  }

  @override
  Future<ResponseModel> guestLogin() async {
    Response response = await apiClient.postData(AppConstants.guestLoginUri, {}, handleError: false);
    if (response.statusCode == 200) {
      saveGuestId(response.body['guest_id'].toString());
      return ResponseModel(true, '${response.body['guest_id']}');
    } else {
      return ResponseModel(false, response.statusText);
    }
  }

  @override
  Future<bool> saveGuestId(String id) async {
    return await sharedPreferences.setString(AppConstants.guestId, id);
  }

  @override
  Future<bool> clearGuestId() async {
    return await sharedPreferences.remove(AppConstants.guestId);
  }

  @override
  bool isGuestLoggedIn() {
    return sharedPreferences.containsKey(AppConstants.guestId);
  }

  @override
  Future<void> saveUserNumberAndPassword(String number, String password, String countryCode) async {
    try {
      await sharedPreferences.setString(AppConstants.userPassword, password);
      await sharedPreferences.setString(AppConstants.userNumber, number);
      await sharedPreferences.setString(AppConstants.userCountryCode, countryCode);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> clearUserNumberAndPassword() async {
    await sharedPreferences.remove(AppConstants.userPassword);
    await sharedPreferences.remove(AppConstants.userCountryCode);
    return await sharedPreferences.remove(AppConstants.userNumber);
  }

  @override
  String getUserCountryCode() {
    return sharedPreferences.getString(AppConstants.userCountryCode) ?? "";
  }

  @override
  String getUserNumber() {
    return sharedPreferences.getString(AppConstants.userNumber) ?? "";
  }

  @override
  String getUserPassword() {
    return sharedPreferences.getString(AppConstants.userPassword) ?? "";
  }

  @override
  String getGuestId() {
    return sharedPreferences.getString(AppConstants.guestId) ?? "";
  }

  @override
  Future<Response> loginWithSocialMedia(SocialLogInBodyModel socialLogInModel) async {
    return await apiClient.postData(AppConstants.socialLoginUri, socialLogInModel.toJson());
  }

  @override
  Future<Response> registerWithSocialMedia(SocialLogInBodyModel socialLogInModel) async {
    return await apiClient.postData(AppConstants.socialRegisterUri, socialLogInModel.toJson());
  }

  @override
  bool isLoggedIn() {
    return sharedPreferences.containsKey(AppConstants.token);
  }

  ///TODO: This methods need to remove from here.
  @override
  Future<bool> saveDmTipIndex(String index) async {
    return await sharedPreferences.setString(AppConstants.dmTipIndex, index);
  }

  ///TODO: This methods need to remove from here.
  @override
  String getDmTipIndex() {
    return sharedPreferences.getString(AppConstants.dmTipIndex) ?? "";
  }

  @override
  Future<bool> clearSharedData({bool removeToken = true}) async {
    if (!GetPlatform.isWeb) {
      FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
      if (removeToken) {
        await apiClient.postData(AppConstants.tokenUri, {"_method": "put", "cm_firebase_token": '@'});
      }
    }
    sharedPreferences.remove(AppConstants.token);
    sharedPreferences.remove(AppConstants.guestId);
    sharedPreferences.setStringList(AppConstants.cartList, []);
    // sharedPreferences.remove(AppConstants.userAddress);
    apiClient.token = null;
    // apiClient.updateHeader(null, null, null,null, null);
    await guestLogin();
    if (sharedPreferences.getString(AppConstants.userAddress) != null) {
      AddressModel? addressModel = AddressModel.fromJson(jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!));
      apiClient.updateHeader(
        null,
        addressModel.zoneIds,
        sharedPreferences.getString(AppConstants.languageCode),
        addressModel.latitude,
        addressModel.longitude,
      );
    }
    return true;
  }

  @override
  bool isNotificationActive() {
    return sharedPreferences.getBool(AppConstants.notification) ?? true;
  }

  @override
  void setNotificationActive(bool isActive) {
    if (isActive) {
      updateToken();
    } else {
      if (!GetPlatform.isWeb) {
        updateToken(notificationDeviceToken: '@');
        FirebaseMessaging.instance.unsubscribeFromTopic(AppConstants.topic);
        if (isLoggedIn()) {
          FirebaseMessaging.instance.unsubscribeFromTopic('zone_${AddressHelper.getAddressFromSharedPref()!.zoneId}_customer');
        }
      }
    }
    sharedPreferences.setBool(AppConstants.notification, isActive);
  }

  @override
  String getUserToken() {
    return sharedPreferences.getString(AppConstants.token) ?? "";
  }

  @override
  Future<bool> saveGuestContactNumber(String number) async {
    return await sharedPreferences.setString(AppConstants.guestNumber, number);
  }

  @override
  String getGuestContactNumber() {
    return sharedPreferences.getString(AppConstants.guestNumber) ?? "";
  }

  @override
  Future<Response> add(SignUpBodyModel signUpModel) async {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
