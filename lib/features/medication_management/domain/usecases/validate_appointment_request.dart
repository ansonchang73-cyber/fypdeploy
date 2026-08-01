// lib/features/medication_management/domain/usecases/validate_appointment_request.dart

enum AppointmentValidationError { missingDateTime, dateTimeInPast }

/// The two guard checks that used to run inline at the top of
/// `_submitCareForm` before booking an appointment.
class ValidateAppointmentRequest {
  const ValidateAppointmentRequest();

  AppointmentValidationError? call(DateTime? selectedDateTime, DateTime now) {
    if (selectedDateTime == null) {
      return AppointmentValidationError.missingDateTime;
    }
    if (selectedDateTime.isBefore(now)) {
      return AppointmentValidationError.dateTimeInPast;
    }
    return null;
  }
}
