class Vendor {
  Vendor({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.gstNumber = '',
    this.paymentTerms = '',
    this.rating = 0,
  });

  final String id;
  String name;
  String contactPerson;
  String email;
  String phone;
  String address;
  String gstNumber;
  String paymentTerms;
  int rating;

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: (json['contactPerson'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      gstNumber: (json['gstNumber'] as String?) ?? '',
      paymentTerms: (json['paymentTerms'] as String?) ?? '',
      rating: (json['rating'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'gstNumber': gstNumber,
      'paymentTerms': paymentTerms,
      'rating': rating,
    };
  }
}
