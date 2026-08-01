class PatientProfile {
  final String id;
  final String fullName;
  final String avatarUrl;
  final String gender;
  final int age;
  final String bloodType;
  final String email;
  
  // ✅ Added fields to match the constructor
  final String primaryDoctor;
  final String doctorContact;
  final String allergies;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.gender,
    required this.age,
    required this.bloodType,
    required this.email,
    required this.primaryDoctor,
    required this.doctorContact,
    required this.allergies,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  factory PatientProfile.fromMap(Map<String, dynamic> data, String userId) {
    return PatientProfile(
      id: userId,
      fullName: data['fullName'] ?? data['name'] ?? 'Unknown Patient',
      avatarUrl: data['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=11',
      gender: data['gender'] ?? 'Not Specified',
      age: data['age'] ?? 0,
      bloodType: data['bloodType'] ?? 'Unknown',
      email: data['email'] ?? 'No Email Provided',
      primaryDoctor: data['primaryDoctor'] ?? '',
      doctorContact: data['doctorContact'] ?? '',
      allergies: data['allergies'] ?? '',
      emergencyContactName: data['emergencyContactName'] ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] ?? '',
    );
  }
}