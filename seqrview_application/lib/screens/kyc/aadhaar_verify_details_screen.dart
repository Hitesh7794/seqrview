import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app/session_controller.dart';

class AadhaarVerifyDetailsScreen extends StatefulWidget {
  final SessionController session;
  
  const AadhaarVerifyDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AadhaarVerifyDetailsScreen> createState() => _AadhaarVerifyDetailsScreenState();
}

class _AadhaarVerifyDetailsScreenState extends State<AadhaarVerifyDetailsScreen> {
  final _fullName = TextEditingController();
  final _address = TextEditingController();
  DateTime? _dob;
  String _gender = "M";
  String? _selectedState;
  String? _selectedDistrict;

  bool _loading = false;
  bool _isDL = false;
  bool _methodChecked = false; // Prevent multiple checks
  String? _error;

  // Indian states list
  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  // Districts by state (simplified - you may want to use a more comprehensive list)
  final Map<String, List<String>> _districtsByState = {
    // --- States ---
    'Andhra Pradesh': [
      'Alluri Sitharama Raju', 'Anakapalli', 'Anantapur', 'Annamayya', 'Bapatla',
      'Chittoor', 'Dr. B.R. Ambedkar Konaseema', 'East Godavari', 'Eluru', 'Guntur',
      'Kakinada', 'Krishna', 'Kurnool', 'Nandyal', 'NTR',
      'Palnadu', 'Parvathipuram Manyam', 'Prakasam', 'Sri Potti Sriramulu Nellore', 'Sri Sathya Sai',
      'Srikakulam', 'Tirupati', 'Visakhapatnam', 'Vizianagaram', 'West Godavari',
      'YSR'
    ],
    'Arunachal Pradesh': [
      'Anjaw', 'Changlang', 'Dibang Valley', 'East Kameng', 'East Siang',
      'Kamle', 'Kra Daadi', 'Kurung Kumey', 'Lepa Rada', 'Lohit',
      'Longding', 'Lower Dibang Valley', 'Lower Siang', 'Lower Subansiri', 'Namsai',
      'Pakke Kessang', 'Papum Pare', 'Shi Yomi', 'Siang', 'Tawang',
      'Tirap', 'Upper Siang', 'Upper Subansiri', 'West Kameng', 'West Siang',
      'Itanagar Capital Complex'
    ],
    'Assam': [
      'Bajali', 'Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon',
      'Cachar', 'Charaideo', 'Chirang', 'Darrang', 'Dhemaji',
      'Dhubri', 'Dibrugarh', 'Dima Hasao', 'Goalpara', 'Golaghat',
      'Hailakandi', 'Hojai', 'Jorhat', 'Kamrup', 'Kamrup Metropolitan',
      'Karbi Anglong', 'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli',
      'Morigaon', 'Nagaon', 'Nalbari', 'Sivasagar', 'Sonitpur',
      'South Salmara-Mankachar', 'Tamulpur', 'Tinsukia', 'Udalguri', 'West Karbi Anglong'
    ],
    'Bihar': [
      'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai',
      'Bhagalpur', 'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran',
      'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad', 'Kaimur',
      'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura',
      'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada',
      'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur',
      'Saran', 'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan',
      'Supaul', 'Vaishali', 'West Champaran'
    ],
    'Chhattisgarh': [
      'Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara',
      'Bijapur', 'Bilaspur', 'Dantewada', 'Dhamtari', 'Durg',
      'Gariaband', 'Gaurela-Pendra-Marwahi', 'Janjgir-Champa', 'Jashpur', 'Kabirdham',
      'Kanker', 'Khairagarh-Chhuikhadan-Gandai', 'Kondagaon', 'Korba', 'Koriya',
      'Mahasamund', 'Manendragarh-Chirimiri-Bharatpur', 'Mohla-Manpur-Ambagarh Chowki', 'Mungeli', 'Narayanpur',
      'Raigarh', 'Raipur', 'Rajnandgaon', 'Sakti', 'Sarangarh-Bilaigarh',
      'Sukma', 'Surajpur', 'Surguja'
    ],
    'Goa': [
      'North Goa', 'South Goa'
    ],
    'Gujarat': [
      'Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha',
      'Bharuch', 'Bhavnagar', 'Botad', 'Chhota Udaipur', 'Dahod',
      'Dang', 'Devbhoomi Dwarka', 'Gandhinagar', 'Gir Somnath', 'Jamnagar',
      'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana',
      'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan',
      'Porbandar', 'Rajkot', 'Sabarkantha', 'Surat', 'Surendranagar',
      'Tapi', 'Vadodara', 'Valsad'
    ],
    'Haryana': [
      'Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad',
      'Gurugram', 'Hisar', 'Jhajjar', 'Jind', 'Kaithal',
      'Karnal', 'Kurukshetra', 'Mahendragarh', 'Nuh', 'Palwal',
      'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa',
      'Sonipat', 'Yamunanagar'
    ],
    'Himachal Pradesh': [
      'Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur',
      'Kullu', 'Lahaul and Spiti', 'Mandi', 'Shimla', 'Sirmaur',
      'Solan', 'Una'
    ],
    'Jharkhand': [
      'Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka',
      'East Singhbhum', 'Garhwa', 'Giridih', 'Godda', 'Gumla',
      'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma', 'Latehar',
      'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi',
      'Sahibganj', 'Seraikela Kharsawan', 'Simdega', 'West Singhbhum'
    ],
    'Karnataka': [
      'Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban',
      'Bidar', 'Chamarajanagar', 'Chikkaballapur', 'Chikkamagaluru', 'Chitradurga',
      'Dakshina Kannada', 'Davanagere', 'Dharwad', 'Gadag', 'Hassan',
      'Haveri', 'Kalaburagi', 'Kodagu', 'Kolar', 'Koppal',
      'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga',
      'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayanagara', 'Vijayapura',
      'Yadgir'
    ],
    'Kerala': [
      'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasargod',
      'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
      'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'
    ],
    'Madhya Pradesh': [
      'Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat',
      'Barwani', 'Betul', 'Bhind', 'Bhopal', 'Burhanpur',
      'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia', 'Dewas',
      'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda',
      'Hoshangabad', 'Indore', 'Jabalpur', 'Jhabua', 'Katni',
      'Khandwa', 'Khargone', 'Maihar', 'Mandla', 'Mandsaur',
      'Mauganj', 'Morena', 'Narsinghpur', 'Neemuch', 'Niwari',
      'Pandhurna', 'Panna', 'Raisen', 'Rajgarh', 'Ratlam',
      'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni',
      'Shahdol', 'Shajapur', 'Sheopur', 'Shivpuri', 'Sidhi',
      'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'
    ],
    'Maharashtra': [
      'Ahmednagar', 'Akola', 'Amravati', 'Aurangabad', 'Beed',
      'Bhandara', 'Buldhana', 'Chandrapur', 'Dhule', 'Gadchiroli',
      'Gondia', 'Hingoli', 'Jalgaon', 'Jalna', 'Kolhapur',
      'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded',
      'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani',
      'Pune', 'Raigad', 'Ratnagiri', 'Sangli', 'Satara',
      'Sindhudurg', 'Solapur', 'Thane', 'Wardha', 'Washim',
      'Yavatmal'
    ],
    'Manipur': [
      'Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West',
      'Jiribam', 'Kakching', 'Kamjong', 'Kangpokpi', 'Noney',
      'Pherzawl', 'Senapati', 'Tamenglong', 'Tengnoupal', 'Thoubal',
      'Ukhrul'
    ],
    'Meghalaya': [
      'East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'Eastern West Khasi Hills',
      'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills',
      'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'
    ],
    'Mizoram': [
      'Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib',
      'Lawngtlai', 'Lunglei', 'Mamit', 'Saiha', 'Saitual',
      'Serchhip'
    ],
    'Nagaland': [
      'Chumoukedima', 'Dimapur', 'Kiphire', 'Kohima', 'Longleng',
      'Mokokchung', 'Mon', 'Niuland', 'Noklak', 'Peren',
      'Phek', 'Shamator', 'Tseminyu', 'Tuensang', 'Wokha',
      'Zunheboto'
    ],
    'Odisha': [
      'Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak',
      'Boudh', 'Cuttack', 'Deogarh', 'Dhenkanal', 'Gajapati',
      'Ganjam', 'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi',
      'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput',
      'Malkangiri', 'Mayurbhanj', 'Nabarangpur', 'Nayagarh', 'Nuapada',
      'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'
    ],
    'Punjab': [
      'Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib',
      'Fazilka', 'Ferozepur', 'Gurdaspur', 'Hoshiarpur', 'Jalandhar',
      'Kapurthala', 'Ludhiana', 'Malerkotla', 'Mansa', 'Moga',
      'Mohali', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar',
      'Sangrur', 'Shaheed Bhagat Singh Nagar', 'Tarn Taran'
    ],
    'Rajasthan': [
      'Ajmer', 'Alwar', 'Anupgarh', 'Balotra', 'Banswara',
      'Baran', 'Barmer', 'Beawar', 'Bharatpur', 'Bhilwara',
      'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa',
      'Deeg', 'Dholpur', 'Didwana-Kuchaman', 'Dudu', 'Dungarpur',
      'Gangapur City', 'Hanumangarh', 'Jaipur', 'Jaipur Rural', 'Jaisalmer',
      'Jalore', 'Jhalawar', 'Jhunjhunu', 'Jodhpur', 'Jodhpur Rural',
      'Karauli', 'Kekri', 'Khairthal-Tijara', 'Kota', 'Kotputli-Behror',
      'Nagaur', 'Neem Ka Thana', 'Pali', 'Phalodi', 'Pratapgarh',
      'Rajsamand', 'Salumbar', 'Sanchore', 'Sawai Madhopur', 'Shahpura',
      'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'
    ],
    'Sikkim': [
      'Gangtok', 'Gyalshing', 'Mangan', 'Namchi', 'Pakyong', 'Soreng'
    ],
    'Tamil Nadu': [
      'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
      'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
      'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam',
      'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai', 'Ramanathapuram',
      'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi', 'Thanjavur',
      'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli', 'Tirupathur',
      'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore',
      'Viluppuram', 'Virudhunagar'
    ],
    'Telangana': [
      'Adilabad', 'Bhadradri Kothagudem', 'Hanumakonda', 'Hyderabad', 'Jagtial',
      'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar',
      'Khammam', 'Komaram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar', 'Mancherial',
      'Medak', 'Medchal-Malkajgiri', 'Mulugu', 'Nagarkurnool', 'Nalgonda',
      'Narayanpet', 'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla',
      'Rangareddy', 'Sangareddy', 'Siddipet', 'Suryapet', 'Vikarabad',
      'Wanaparthy', 'Warangal', 'Yadadri Bhuvanagiri'
    ],
    'Tripura': [
      'Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala',
      'South Tripura', 'Unakoti', 'West Tripura'
    ],
    'Uttar Pradesh': [
      'Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha',
      'Auraiya', 'Ayodhya', 'Azamgarh', 'Baghpat', 'Bahraich',
      'Ballia', 'Balrampur', 'Banda', 'Barabanki', 'Bareilly',
      'Basti', 'Bhadohi', 'Bijnor', 'Budaun', 'Bulandshahr',
      'Chandauli', 'Chitrakoot', 'Deoria', 'Etah', 'Etawah',
      'Farrukhabad', 'Fatehpur', 'Firozabad', 'Gautam Buddha Nagar', 'Ghaziabad',
      'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur', 'Hapur',
      'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi',
      'Kannauj', 'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi',
      'Kheri', 'Kushinagar', 'Lalitpur', 'Lucknow', 'Maharajganj',
      'Mahoba', 'Mainpuri', 'Mathura', 'Mau', 'Meerut',
      'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh',
      'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal',
      'Sant Kabir Nagar', 'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar',
      'Sitapur', 'Sonbhadra', 'Sultanpur', 'Unnao', 'Varanasi'
    ],
    'Uttarakhand': [
      'Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun',
      'Haridwar', 'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag',
      'Tehri Garhwal', 'Udham Singh Nagar', 'Uttarkashi'
    ],
    'West Bengal': [
      'Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur',
      'Darjeeling', 'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram',
      'Kalimpong', 'Kolkata', 'Malda', 'Murshidabad', 'Nadia',
      'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur', 'Purba Bardhaman', 'Purba Medinipur',
      'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'
    ],

    // --- Union Territories ---
    'Andaman and Nicobar Islands': [
      'Nicobar', 'North and Middle Andaman', 'South Andaman'
    ],
    'Chandigarh': [
      'Chandigarh'
    ],
    'Dadra and Nagar Haveli and Daman and Diu': [
      'Dadra and Nagar Haveli', 'Daman', 'Diu'
    ],
    'Delhi': [
      'Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi',
      'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi',
      'West Delhi'
    ],
    'Jammu and Kashmir': [
      'Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda',
      'Ganderbal', 'Jammu', 'Kathua', 'Kishtwar', 'Kulgam',
      'Kupwara', 'Poonch', 'Pulwama', 'Rajouri', 'Ramban',
      'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur'
    ],
    'Ladakh': [
      'Kargil', 'Leh'
    ],
    'Lakshadweep': [
      'Lakshadweep'
    ],
    'Puducherry': [
      'Karaikal', 'Mahe', 'Puducherry', 'Yanam'
    ],
  };

  List<String> get _districts {
    if (_selectedState == null) return [];
    return _districtsByState[_selectedState!] ?? [];
  }

  String _prettyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (data is Map && data['message'] != null) return data['message'].toString();
      return "Network/API error (${e.response?.statusCode ?? 'no status'})";
    }
    return e.toString();
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  @override
  void initState() {
    super.initState();
    // User will manually fill in details - no auto-fill
    _checkMethod();
  }

  Future<void> _checkMethod() async {
    // Prevent multiple simultaneous checks
    if (_methodChecked) return;
    
    try {
      _methodChecked = true;
      final profileRes = await widget.session.api.dio.get('/api/operators/profile/');
      final profileData = profileRes.data as Map<String, dynamic>?;
      final method = profileData?['verification_method']?.toString();
      if (mounted) {
        setState(() {
          _isDL = method == 'DL';
        });
      }
    } catch (e) {
      // If profile fetch fails (401, network error, etc.), default to Aadhaar (show DOB)
      // Don't retry - just use default
      if (mounted) {
        setState(() {
          _isDL = false; // Default to Aadhaar
        });
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year - 10, 12, 31),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _verify() async {
    final name = _fullName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter your full name");
      return;
    }
    
    // DOB only required for Aadhaar, not for DL (already collected at DL input screen)
    if (!_isDL && _dob == null) {
      setState(() => _error = "Please select Date of Birth");
      return;
    }

    if (_selectedState == null || _selectedState!.isEmpty) {
      setState(() => _error = "Please select State");
      return;
    }

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      setState(() => _error = "Please select District");
      return;
    }

    final address = _address.text.trim();
    if (address.isEmpty) {
      setState(() => _error = "Please enter your full address");
      return;
    }

    final kycUid = widget.session.kycSessionUid;
    if (kycUid == null || kycUid.isEmpty) {
      setState(() => _error = "KYC session missing. Please restart verification.");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      // Determine endpoint based on verification method
      String endpoint = _isDL ? '/api/kyc/dl/verify-details/' : '/api/kyc/aadhaar/verify-details/';
      
      // Build request data
      final requestData = <String, dynamic>{
        "kyc_session_uid": kycUid,
        "full_name": name,
        "gender": _gender,
        "state": _selectedState,
        "district": _selectedDistrict,
        "address": address,
      };
      
      // Only include DOB for Aadhaar
      if (!_isDL && _dob != null) {
        requestData["date_of_birth"] = _fmtDate(_dob!);
      }

      final res = await widget.session.api.dio.post(
        endpoint,
        data: requestData,
      );

      final data = res.data;
      final match = data is Map ? data['match'] : false;
      final next = data is Map ? data['next']?.toString() : null;

      if (match == true) {
        // Details verified successfully - proceed to face match (which combines liveness + match)
        await widget.session.bootstrap();
      } else {
        // Mismatch - show error and allow retry
        final mismatches = data is Map ? data['mismatches'] : null;
        final message = data is Map ? data['message']?.toString() : null;
        
        String errorMsg = message ?? "Details do not match. Please verify and try again.";
        if (mismatches is Map) {
          final issues = <String>[];
          if (mismatches['name'] == true) issues.add("Name");
          if (mismatches['date_of_birth'] == true) issues.add("Date of Birth");
          if (mismatches['gender'] == true) issues.add("Gender");
          if (issues.isNotEmpty) {
            errorMsg = "${message}\nMismatch in: ${issues.join(", ")}";
          }
        }
        
        setState(() => _error = errorMsg);
      }
    } catch (e) {
      setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _dob == null ? "Select DOB" : _fmtDate(_dob!);

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please enter your details as they appear on your ID document:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: "Full Name",
                hintText: "Enter your full name as on your ID",
                border: OutlineInputBorder(),
              ),
            ),
            // Only show DOB picker for Aadhaar, not for DL (DOB already collected at DL input screen)
            if (!_isDL) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _pickDob,
                      child: Text(dobText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: "M", child: Text("Male")),
                      DropdownMenuItem(value: "F", child: Text("Female")),
                      DropdownMenuItem(value: "O", child: Text("Other")),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _gender = v ?? "M"),
                  ),
                ],
              ),
            ] else ...[
              // For DL, only show gender dropdown
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "M", child: Text("Male")),
                  DropdownMenuItem(value: "F", child: Text("Female")),
                  DropdownMenuItem(value: "O", child: Text("Other")),
                ],
                onChanged: _loading ? null : (v) => setState(() => _gender = v ?? "M"),
              ),
            ],
            // State and District dropdowns (for both Aadhaar and DL)
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(
                labelText: "State *",
                border: OutlineInputBorder(),
              ),
              items: _states.map((state) => DropdownMenuItem(
                value: state,
                child: Text(state),
              )).toList(),
              onChanged: _loading ? null : (v) {
                setState(() {
                  _selectedState = v;
                  _selectedDistrict = null; // Reset district when state changes
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: const InputDecoration(
                labelText: "District *",
                border: OutlineInputBorder(),
                hintText: "Select state first",
              ),
              items: _districts.map((district) => DropdownMenuItem(
                value: district,
                child: Text(district),
              )).toList(),
              onChanged: _loading || _selectedState == null ? null : (v) {
                setState(() => _selectedDistrict = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Full Address *",
                hintText: "Enter your complete address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.withOpacity(0.08),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Verify & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

