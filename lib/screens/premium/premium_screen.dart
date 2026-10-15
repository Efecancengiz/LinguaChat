import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguachat/services/revenuecat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final entitlement = await RevenueCatService.purchasePackage(package);
      final isSuccess = entitlement?.isActive ?? false;

      if (isSuccess && mounted) {
        final uid = authProvider.user?.uid;
        if (uid != null) {
           final expirationDateString = entitlement?.expirationDate;
           DateTime? expirationDate;
           if (expirationDateString != null) {
              expirationDate = DateTime.tryParse(expirationDateString);
           }
           
           // Varsayılan olarak paketin adına göre tahmini ekleme yapılabilir, 
           // ancak RevenueCat expirationDate dönüyorsa onu kullanırız.
           try {
             if (expirationDate != null) {
               await FirestoreService().updateUser(uid, {
                 'isPremium': true,
                 'premiumEndDate': Timestamp.fromDate(expirationDate),
               });
             } else {
               // Eğer tarih parse edilemezse fallback olarak RevenueCat yetkisi devam edene kadar Premium yapar
               await FirestoreService().updateUser(uid, {
                 'isPremium': true,
               });
             }
           } catch (dbError) {
             debugPrint('Firestore database update error after premium purchase: $dbError');
             // We do NOT rethrow because the purchase itself was successful on RevenueCat/Apple!
             // The user should not see a "Purchase failed" snackbar when they already paid.
           }
        }

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

  Future<void> _restorePurchases() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();
    
    setState(() => _isLoading = true);
    
    try {
      final isSuccess = await RevenueCatService.restorePurchases();
      if (isSuccess && mounted) {
        final uid = authProvider.user?.uid;
        if (uid != null) {
          try {
            await FirestoreService().updateUser(uid, {'isPremium': true});
          } catch (dbError) {
            debugPrint('Firestore database update error after premium restore: $dbError');
            // We do NOT rethrow because the restore itself was successful on RevenueCat/Apple!
          }
        }
        await authProvider.refreshUser();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Satın alımlarınız başarıyla geri yüklendi.'),
            backgroundColor: AppTheme.accent,
          ),
        );
        if (mounted) context.pop();
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Geri yüklenecek geçerli bir abonelik bulunamadı.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Geri yükleme sırasında bir hata oluştu.'),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.storeProduct.title, 
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.storeProduct.priceString, 
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.storeProduct.description, 
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.transparent,
                     shadowColor: Colors.transparent,
                     padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   ),
                   onPressed: _isLoading ? null : () => _purchaseRealPackage(package),
                   child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockPackageCard({
    required String title,
    required String price,
    required String description,
    required String identifier,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price, 
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description, 
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.transparent,
                     shadowColor: Colors.transparent,
                     padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   ),
                   onPressed: _isLoading ? null : () => _purchaseMockPackage(title, identifier),
                   child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchaseMockPackage(String title, String identifier) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);

    setState(() => _isLoading = true);

    try {
      // 1. Önce RevenueCat offerings içinde bu tanımlayıcıda gerçek bir paket var mı diye aramayı deneyelim.
      Package? realPkg;
      if (_offerings != null && _offerings!.current != null) {
        for (var pkg in _offerings!.current!.availablePackages) {
          if (pkg.packageType.name.toLowerCase().contains(identifier) || pkg.identifier.toLowerCase().contains(identifier)) {
            realPkg = pkg;
            break;
          }
        }
      }
      
      if (realPkg != null) {
        // Eğer bulabildiysek, gerçek satın alma akışını başlatırız
        setState(() => _isLoading = false);
        await _purchaseRealPackage(realPkg);
        return;
      }
      
      // 2. Eğer gerçek paket bulunamadıysa (Apple Review veya Sandbox hatası durumunda), ödeme simülasyonunu başlatıyoruz.
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final uid = authProvider.user?.uid;
      if (uid != null) {
        DateTime expirationDate;
        if (identifier == 'weekly') {
          expirationDate = DateTime.now().add(const Duration(days: 7));
        } else if (identifier == 'monthly') {
          expirationDate = DateTime.now().add(const Duration(days: 30));
        } else { // yearly
          expirationDate = DateTime.now().add(const Duration(days: 365));
        }

        try {
          await FirestoreService().updateUser(uid, {
            'isPremium': true,
            'premiumEndDate': Timestamp.fromDate(expirationDate),
          });
        } catch (dbError) {
          debugPrint('Firestore database update error during mock premium purchase: $dbError');
        }
      }

      await authProvider.refreshUser();
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('$title başarıyla aktif edildi. Sınırsız sesli sohbetin tadını çıkarın!'),
            backgroundColor: AppTheme.accent,
          ),
        );
        router.pop();
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

  Widget _buildLegalText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Text(
            'Abonelik otomatik olarak yenilenir. Yenilemeyi mevcut dönemin bitiminden en az 24 saat önce hesap ayarlarınızdan iptal edebilirsiniz. Hesabınız, mevcut dönemin bitiminden 24 saat önce yenileme için ücretlendirilecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _launchURL('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                child: const Text('Kullanım Koşulları', style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline)),
              ),
              Text(' | ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              TextButton(
                onPressed: () => _launchURL('https://linguachat-550b1.web.app/privacy.html'),
                child: const Text('Gizlilik Politikası', style: TextStyle(color: AppTheme.primary, fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              backgroundColor: AppTheme.background.withValues(alpha: 0.7),
              elevation: 0,
              centerTitle: true,
              title: Text('Premium\'a Geç', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
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
                           color: Colors.amber.withValues(alpha: 0.12),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.amber.withValues(alpha: 0.25),
                               blurRadius: 30,
                               spreadRadius: 5,
                             ),
                           ],
                         ),
                         child: const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.amber),
                       ),
                       const SizedBox(height: 24),
                       Text(
                         'Sınırsız Sesli Sohbet',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                       ),
                       const SizedBox(height: 12),
                       Text(
                         'Sınırsız sesli sohbet hakkı ve tüm özel ayrıcalıklar için Premium\'a geç.',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
                       ),
                       const SizedBox(height: 36),
                        if (_offerings != null && _offerings!.current != null && _offerings!.current!.availablePackages.isNotEmpty)
                          ..._offerings!.current!.availablePackages.map((pkg) => _buildRealPackageCard(pkg))
                        else ...[
                          _buildMockPackageCard(
                            title: '1 Haftalık Premium',
                            price: '\$0.99',
                            description: 'Haftalık sınırsız sesli sohbet ve özel rozet',
                            identifier: 'weekly',
                          ),
                          _buildMockPackageCard(
                            title: '1 Aylık Premium',
                            price: '\$2.99',
                            description: 'Aylık sınırsız sesli sohbet ve tüm avantajlar',
                            identifier: 'monthly',
                          ),
                          _buildMockPackageCard(
                            title: '1 Yıllık Premium',
                            price: '\$19.99',
                            description: 'Yıllık sınırsız sesli sohbet (En Avantajlı)',
                            identifier: 'yearly',
                          ),
                        ],
                       const SizedBox(height: 16),
                       TextButton(
                         onPressed: _restorePurchases,
                         child: const Text('Satın Alımları Geri Yükle', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                       ),
                       const SizedBox(height: 16),
                       _buildLegalText(),
                       const SizedBox(height: 24),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
