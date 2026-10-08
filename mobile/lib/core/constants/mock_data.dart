import '../../models/vehicle_model.dart';
import '../../models/service_request_model.dart';
import '../../models/provider_model.dart';

class MockData {
  MockData._();

  // ── Vehicle Manufacturers by Type ──────────────────────────────────
  static const Map<String, List<String>> manufacturersByType = {
    'Bike': ['Hero', 'Honda', 'TVS', 'Bajaj', 'Royal Enfield', 'KTM', 'Yamaha', 'Suzuki'],
    'Car': ['Maruti Suzuki', 'Hyundai', 'Tata', 'Honda', 'Toyota', 'Mahindra', 'Kia', 'Ford', 'Volkswagen', 'Skoda'],
    'Van': ['Maruti Suzuki', 'Toyota', 'Force Motors', 'Tata', 'Kia'],
    'Auto': ['Bajaj', 'TVS', 'Piaggio', 'Mahindra'],
    'Bus': ['Ashok Leyland', 'Tata', 'Eicher', 'SML Isuzu', 'Force Motors', 'Volvo'],
    'Light Commercial Vehicle': ['Tata', 'Mahindra', 'Ashok Leyland', 'Eicher', 'Force Motors', 'BharatBenz', 'SML Isuzu'],
    'Heavy Vehicle': ['Ashok Leyland', 'Tata', 'BharatBenz', 'Eicher', 'Volvo', 'Scania', 'MAN', 'Mercedes-Benz', 'KAMAZ'],
  };

  // ── Vehicle Models by Manufacturer ───────────────────────────────
  static const Map<String, List<String>> modelsByManufacturer = {
    // Bikes
    'Hero': ['Splendor Plus', 'HF Deluxe', 'Passion Pro', 'Glamour', 'Xtreme 160R', 'XPulse 200'],
    'Honda': ['Activa 6G', 'SP 125', 'Shine', 'Unicorn', 'CB350', 'Hornet 2.0', 'City (Car)', 'Amaze (Car)', 'WR-V (Car)'],
    'TVS': ['Apache RTR 160', 'Jupiter', 'Ntorq 125', 'Raider 125', 'Star City+'],
    'Bajaj': ['Pulsar 150', 'Pulsar NS200', 'Dominar 400', 'Avenger 220', 'RE Auto', 'Maxima Z (Auto)'],
    'Royal Enfield': ['Classic 350', 'Bullet 350', 'Meteor 350', 'Hunter 350', 'Himalayan', 'Super Meteor 650'],
    'KTM': ['Duke 125', 'Duke 200', 'Duke 390', 'Adventure 390'],
    'Yamaha': ['FZ-S V3', 'MT-15', 'R15 V4', 'FZS-FI V3', 'RayZR'],
    'Suzuki': ['Access 125', 'Burgman Street', 'Gixxer 150', 'V-Strom SX'],

    // Cars
    'Maruti Suzuki': ['Swift', 'Baleno', 'Alto K10', 'WagonR', 'Brezza', 'Ertiga', 'Fronx', 'Dzire', 'Celerio', 'Eeco'],
    'Hyundai': ['Grand i10 Nios', 'i20', 'Venue', 'Creta', 'Tucson', 'Verna', 'Exter', 'Alcazar'],
    'Tata': ['Nexon', 'Punch', 'Tiago', 'Harrier', 'Safari', 'Altroz', '407 (LCV)', '909 (HV)', '1412 LPT (HV)', '1618 (HV)', 'Signa 2825.TK (HV)'],
    'Toyota': ['Innova Crysta', 'Fortuner', 'Hilux', 'Glanza', 'Urban Cruiser Hyryder', 'Vellfire'],
    'Mahindra': ['Thar', 'XUV700', 'Scorpio-N', 'Bolero', 'Bolero Neo', 'XUV300', 'Supro (Van)', 'Jeeto (LCV)', 'Maxximo (LCV)'],
    'Kia': ['Seltos', 'Sonet', 'Carens', 'EV6'],
    'Ford': ['Ecosport', 'Endeavour'],
    'Volkswagen': ['Polo', 'Virtus', 'Taigun'],
    'Skoda': ['Slavia', 'Kushaq', 'Kodiaq'],

    // Vans
    'Force Motors': ['Traveller', 'Gurkha', 'Trax Toofan', 'Urbania'],

    // Autos
    'Piaggio': ['Ape City Plus', 'Ape DX'],

    // Heavy Vehicles - Ashok Leyland
    'Ashok Leyland': [
      '2820 6x4 Tipper', '3120 8x2 Truck', '5530 Haulage', 'BOSS 1215 (LCV)',
      'DOST+ (LCV)', 'Phoenix 2518', 'Captain 4940', 'U-Truck 4923',
      '12M Bus Lynx', 'Viking CNG Bus',
    ],
    // BharatBenz
    'BharatBenz': [
      '1015R (LCV)', '1617R Medium Truck', '2523R Heavy Duty', '3523R Tractor',
      '4028T Tractor-Trailer', '5528TT Prime Mover',
    ],
    // Eicher
    'Eicher': [
      'Pro 1049 (LCV)', 'Pro 2049 Medium', 'Pro 3015 Medium', 'Pro 6028 Heavy',
      'Pro 6031 Tractor', 'Skyline Bus',
    ],
    // Volvo
    'Volvo': ['FM 380', 'FH 460', 'FMX 460', 'B11R Bus', 'B8R Bus', '9400 Bus'],
    // Scania
    'Scania': ['R 500', 'P 360', 'G 410', 'K 360 IB Bus'],
    // MAN
    'MAN': ['TGS 26.480', 'TGX 18.480', 'CLA 28.280', 'Lion\'s Coach Bus'],
    // Mercedes-Benz
    'Mercedes-Benz': ['Actros 2658', 'Arocs 3348', 'Atego 916'],
    // KAMAZ
    'KAMAZ': ['65201 6x6', '65115 Tipper'],

    // Bus-specific
    'SML Isuzu': ['Samrat GS', 'Super GS', 'Loadking Gold'],
  };

  // ── Mock User Vehicles ────────────────────────────────────────────
  static List<VehicleModel> get userVehicles => [
        const VehicleModel(
          id: 'v1',
          type: 'Heavy Vehicle',
          manufacturer: 'Ashok Leyland',
          model: '2820 6x4 Tipper',
          plateNumber: 'TN 38 AB 1234',
          year: '2020',
          color: 'White',
          isDefault: true,
        ),
        const VehicleModel(
          id: 'v2',
          type: 'Light Commercial Vehicle',
          manufacturer: 'Tata',
          model: '407 (LCV)',
          plateNumber: 'TN 38 CD 5678',
          year: '2019',
          color: 'Blue',
          isDefault: false,
        ),
      ];

  // ── Mock Service Requests ─────────────────────────────────────────
  static List<ServiceRequestModel> get recentRequests => [
        ServiceRequestModel(
          id: 'req001',
          vehiclePlate: 'TN 38 AB 1234',
          vehicleModel: 'Ashok Leyland 2820',
          serviceType: 'Mechanic',
          problem: 'Engine overheating',
          status: RequestStatus.completed,
          date: DateTime.now().subtract(const Duration(days: 2)),
          providerName: 'Rajan Auto Works',
          totalAmount: 1500,
          location: 'NH 44, Krishnagiri',
        ),
        ServiceRequestModel(
          id: 'req002',
          vehiclePlate: 'TN 38 AB 1234',
          vehicleModel: 'Ashok Leyland 2820',
          serviceType: 'Puncture',
          problem: 'Front left tyre puncture',
          status: RequestStatus.completed,
          date: DateTime.now().subtract(const Duration(days: 8)),
          providerName: 'Kareem Tyre Centre',
          totalAmount: 500,
          location: 'Hosur By-Pass Road',
        ),
        ServiceRequestModel(
          id: 'req003',
          vehiclePlate: 'TN 38 CD 5678',
          vehicleModel: 'Tata 407',
          serviceType: 'Tow',
          problem: 'Vehicle breakdown, won\'t start',
          status: RequestStatus.cancelled,
          date: DateTime.now().subtract(const Duration(days: 15)),
          providerName: '',
          totalAmount: 0,
          location: 'Salem - Coimbatore Highway',
        ),
      ];

  // ── Mock Nearby Providers ─────────────────────────────────────────
  static List<ProviderModel> get nearbyProviders => [
        const ProviderModel(
          id: 'p1',
          name: 'Rajan Auto Works',
          type: 'Mechanic',
          rating: 4.7,
          totalJobs: 312,
          distanceKm: 2.1,
          eta: '8 min',
          isAvailable: true,
          phone: '+91 98765 43210',
          location: 'NH 44 Service Road, Krishnagiri',
        ),
        const ProviderModel(
          id: 'p2',
          name: 'Kareem Tyre Centre',
          type: 'Puncture',
          rating: 4.5,
          totalJobs: 567,
          distanceKm: 3.4,
          eta: '12 min',
          isAvailable: true,
          phone: '+91 99001 12345',
          location: 'Bus Stand Road, Hosur',
        ),
        const ProviderModel(
          id: 'p3',
          name: 'Siva Recovery Services',
          type: 'Tow',
          rating: 4.8,
          totalJobs: 189,
          distanceKm: 4.2,
          eta: '15 min',
          isAvailable: true,
          phone: '+91 87654 32109',
          location: 'Salem NH, Dharmapuri',
        ),
        const ProviderModel(
          id: 'p4',
          name: 'Quick Fix Garage',
          type: 'Mechanic',
          rating: 4.2,
          totalJobs: 201,
          distanceKm: 5.8,
          eta: '20 min',
          isAvailable: true,
          phone: '+91 76543 21098',
          location: 'Industrial Area, Hosur',
        ),
      ];

  // ── Mock Problem List by Service Type ────────────────────────────
  static const Map<String, List<String>> problemsByService = {
    'Mechanic': [
      'Engine won\'t start',
      'Engine overheating',
      'Strange engine noise',
      'Gear/Transmission issue',
      'Brake failure',
      'Clutch problem',
      'Electrical fault',
      'AC not working',
      'Oil leakage',
      'Fuel system issue',
      'Suspension/Steering problem',
      'Other mechanical issue',
    ],
    'Puncture': [
      'Front tyre puncture',
      'Rear tyre puncture',
      'Multiple tyre punctures',
      'Tyre blowout',
      'Need spare tyre fitting',
      'Tyre bead damage',
    ],
    'Tow': [
      'Complete breakdown',
      'Accident recovery',
      'Vehicle stuck in mud/ditch',
      'Engine seized',
      'Vehicle flooded',
      'Need transport to workshop',
    ],
    'Battery': [
      'Battery dead/won\'t start',
      'Battery jump-start needed',
      'Battery replacement needed',
      'Alternator issue',
    ],
    'Fuel': [
      'Ran out of fuel',
      'Wrong fuel filled',
      'Fuel delivery needed',
    ],
  };

  // ── Quick Services ────────────────────────────────────────────────
  static const List<Map<String, dynamic>> quickServices = [
    {'label': 'Mechanic', 'icon': 'build_rounded', 'color': 0xFF1565C0},
    {'label': 'Puncture', 'icon': 'tire_repair_rounded', 'color': 0xFF6A1B9A},
    {'label': 'Tow / Recovery', 'icon': 'local_shipping_rounded', 'color': 0xFFE65100},
    {'label': 'Battery', 'icon': 'battery_charging_full_rounded', 'color': 0xFF2E7D32},
    {'label': 'Fuel', 'icon': 'local_gas_station_rounded', 'color': 0xFFF57F17},
  ];

  // ── Provider Incoming Requests (mock) ─────────────────────────────
  static List<ServiceRequestModel> get providerIncomingRequests => [
        ServiceRequestModel(
          id: 'preq001',
          vehiclePlate: 'TN 09 ZX 9900',
          vehicleModel: 'Ashok Leyland 2820',
          serviceType: 'Mechanic',
          problem: 'Engine problem',
          status: RequestStatus.pending,
          date: DateTime.now(),
          providerName: '',
          totalAmount: 0,
          location: 'NH 48, Near Vaniyambadi Toll',
          distanceFromProvider: 4.2,
        ),
      ];

  // ── Provider service history ──────────────────────────────────────
  static List<ServiceRequestModel> get providerServiceHistory => [
        ServiceRequestModel(
          id: 'psh001',
          vehiclePlate: 'TN 22 XX 7766',
          vehicleModel: 'Tata Signa 2825',
          serviceType: 'Mechanic',
          problem: 'Turbocharger issue',
          status: RequestStatus.completed,
          date: DateTime.now().subtract(const Duration(hours: 3)),
          providerName: 'Rajan Auto Works',
          totalAmount: 2200,
          location: 'Vellore - Katpadi Road',
        ),
        ServiceRequestModel(
          id: 'psh002',
          vehiclePlate: 'TN 38 AB 1234',
          vehicleModel: 'BharatBenz 2523R',
          serviceType: 'Mechanic',
          problem: 'Brake adjustment',
          status: RequestStatus.completed,
          date: DateTime.now().subtract(const Duration(days: 1)),
          providerName: 'Rajan Auto Works',
          totalAmount: 800,
          location: 'Krishnagiri Bypass',
        ),
      ];
}
