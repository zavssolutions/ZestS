import "package:dio/dio.dart";
import "package:flutter/material.dart";

void showFriendlyErrorSnackBar(BuildContext context, Object error) {
  String message = "Something went wrong. Please try again.";

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = "Request timed out while contacting Render backend.";
    } else if (error.response?.statusCode == 401) {
      message = "Your session expired. Please login again.";
    } else if (error.response?.statusCode == 403) {
      message = "You do not have permission for this action.";
    }
  }

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
