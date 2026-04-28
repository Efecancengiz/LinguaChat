import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/revenuecat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final offerings = await RevenueCatService.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
      });
    }
  }

  Future<void> _purchaseRealPackage(Package package) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);

    setState(() => _isLoading = true);

    try {
      final isSuccess = await RevenueCatService.purchasePackage(package);
      if (isSuccess && mounted) {
        await authProvider.refreshUser();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Satın alım başarılı. Premium durumu sunucudan eşitleniyor.'),
            backgroundColor: AppTheme.accent,
          ),
        );
        if (mounted) router.pop();
      } else if (!isSuccess && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('İşlem iptal edildi veya başarısız.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Sistem hatası. Satın alım yapılamadı.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRealPackageCard(Package package) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.storeProduct.title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(package.storeProduct.priceString, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(package.storeProduct.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.transparent,
                       shadowColor: Colors.transparent,
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     ),
                     onPressed: _isLoading ? null : () => _purchaseRealPackage(package),
                     child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Production build'da RevenueCat yapılandırılmamışsa gösterilen bilgi kartı.
  Widget _buildUnconfiguredCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.construction_rounded, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Ödeme Sistemi Yakında',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Premium abonelik seçenekleri yakında burada olacak. '
            'Şu an için lütfen daha sonra tekrar deneyin.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: AppTheme.background.withValues(alpha: 0.5),
              elevation: 0,
              centerTitle: true,
              title: const Text('Premium\'a Geç', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Stack(
          children: [
            // Background aurora glow
            Positioned(
              top: -100,
              left: -50,
              right: -50,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                       Container(
                         padding: const EdgeInsets.all(24),
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: Colors.amber.withValues(alpha: 0.1),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.amber.withValues(alpha: 0.2),
                               blurRadius: 30,
                               spreadRadius: 5,
                             ),
                           ],
                         ),
                         child: const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.amber),
                       ),
                       const SizedBox(height: 24),
                       const Text(
                         'Sesli Sohbet İçin Premium Özellik Al',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                       ),
                       const SizedBox(height: 12),
                       const Text(
                         'Sesli sohbet sadece premium üyelikler içindir.',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
                       ),
                       const SizedBox(height: 40),
                       if (_offerings != null && _offerings!.current != null && _offerings!.current!.availablePackages.isNotEmpty)
                         ..._offerings!.current!.availablePackages.map((pkg) => _buildRealPackageCard(pkg))
                       else ...[
                         _buildUnconfiguredCard(),
                       ],
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
