import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/vehicle_card_widget.dart';
import '../../../widgets/rr_loading.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final vehicles = await VehicleService.getMyVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load vehicles. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToAddVehicle() async {
    final added = await Navigator.pushNamed(context, AppRoutes.addVehicle);
    if (added == true) {
      _loadVehicles(); // refresh list after adding
    }
  }

  Future<void> _navigateToDetails(VehicleModel vehicle) async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.vehicleDetails,
      arguments: vehicle,
    );
    if (changed == true) {
      _loadVehicles(); // refresh after edit/delete
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _navigateToAddVehicle,
            tooltip: 'Add Vehicle',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadVehicles,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return RREmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No Vehicles Added',
        subtitle: 'Add your vehicle to request roadside assistance.',
        actionLabel: 'Add Vehicle',
        onAction: _navigateToAddVehicle,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVehicles,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _vehicles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == _vehicles.length) {
            return OutlinedButton.icon(
              onPressed: _navigateToAddVehicle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Another Vehicle'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return VehicleCardWidget(
            vehicle: _vehicles[i],
            onTap: () => _navigateToDetails(_vehicles[i]),
          );
        },
      ),
    );
  }
}
