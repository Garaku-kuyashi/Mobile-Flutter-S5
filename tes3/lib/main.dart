import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const CheckoutSuperApp());
}

// ==========================================
// 1. FORMATTER MATA UANG RUPIAH
// ==========================================
class CurrencyRupiahFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) return newValue.copyWith(text: '');

    final double? val = double.tryParse(cleanDigits);
    if (val == null) return newValue;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final formatted = formatter.format(val);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ==========================================
// 2. ROOT APLIKASI
// ==========================================
class CheckoutSuperApp extends StatelessWidget {
  const CheckoutSuperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokoKita Checkout Wizard 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D9488), // Warna Teal Elegan
        fontFamily: 'sans-serif', // Mencegah error font tofu di Web
      ),
      home: const FormCheckoutPage(),
    );
  }
}

// ==========================================
// 3. HALAMAN FORMULIR CHECKOUT AMAN
// ==========================================
class FormCheckoutPage extends StatefulWidget {
  const FormCheckoutPage({super.key});

  @override
  State<FormCheckoutPage> createState() => _FormCheckoutPageState();
}

class _FormCheckoutPageState extends State<FormCheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  // 1. Pengendali Input Teks (Text Editing Controllers)
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _nominalController = TextEditingController();

  // 2. Pengatur Fokus Kursor (FocusNodes)
  final _emailFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _nominalFocus = FocusNode();

  // 3. Status State Formulir
  bool _isFormDirty = false;
  bool _sembunyikanPin = true;
  String _metodeKurirDipilih = 'Pilih Pengiriman';
  DateTime? _tanggalPengiriman;
  String? _metodePembayaran;
  bool _setujuSyarat = false;

  @override
  void dispose() {
    // Selalu bersihkan semua controller dan focus node untuk cegah memory leak!
    _namaController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _nominalController.dispose();
    _emailFocus.dispose();
    _pinFocus.dispose();
    _nominalFocus.dispose();
    super.dispose();
  }

  void _tandaiFormKotor() {
    if (!_isFormDirty) {
      setState(() => _isFormDirty = true);
    }
  }

  // Dialog Konfirmasi saat pengguna hendak membatalkan pengisian
  Future<bool> _konfirmasiKeluar() async {
    final bool? hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pengisian?'),
        content: const Text('Data pemesanan yang Anda ketik belum disimpan dan akan hilang jika keluar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // Batal keluar
            child: const Text('Lanjut Mengisi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // Setuju keluar
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    return hasil ?? false;
  }

  // Pemilih Tanggal Kalender (showDatePicker)
  Future<void> _pilihTanggalPengiriman() async {
    final DateTime? hasil = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'PILIH ESTIMASI TANGGAL PENGIRIMAN',
    );

    if (hasil != null) {
      setState(() {
        _tanggalPengiriman = hasil;
        _tandaiFormKotor();
      });
    }
  }

  // Pemilih Kurir Bawah (showModalBottomSheet)
  void _pilihKurirModal() {
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Opsi Pengiriman', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('Kurir Kilat Instan (2 Jam)'),
              subtitle: const Text('Rp 25.000'),
              onTap: () => Navigator.pop(ctx, 'Kurir Kilat Instan (Rp 25.000)'),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping, color: Colors.teal),
              title: const Text('Kurir Kargo Standar (2 Hari)'),
              subtitle: const Text('Rp 12.000'),
              onTap: () => Navigator.pop(ctx, 'Kurir Kargo Standar (Rp 12.000)'),
            ),
          ],
        ),
      ),
    ).then((pilihan) {
      if (pilihan != null) {
        setState(() {
          _metodeKurirDipilih = pilihan;
          _tandaiFormKotor();
        });
      }
    });
  }

  // Eksekusi Simpan & Validasi Terpusat
  void _simpanTransaksi() {
    if (_formKey.currentState!.validate()) {
      if (_tanggalPengiriman == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Harap pilih estimasi tanggal pengiriman!'), backgroundColor: Colors.orange),
        );
        return;
      }

      if (_metodeKurirDipilih == 'Pilih Pengiriman') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Harap tentukan metode kurir pengiriman!'), backgroundColor: Colors.orange),
        );
        return;
      }

      if (_metodePembayaran == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Harap pilih metode pembayaran!'), backgroundColor: Colors.orange),
        );
        return;
      }

      if (!_setujuSyarat) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Harap centang persetujuan Syarat & Ketentuan!'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isFormDirty = false); // Bersihkan status kotor form

      final tglFormat = DateFormat('dd MMMM yyyy').format(_tanggalPengiriman!);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          title: const Text('Pemesanan Sukses!'),
          content: Text(
            'Terima kasih, ${_namaController.text}!\n\n'
            '• Nominal: ${_nominalController.text}\n'
            '• Estimasi Tiba: $tglFormat\n'
            '• Kurir: $_metodeKurirDipilih\n'
            '• Metode Bayar: $_metodePembayaran\n\n'
            'Bukti transaksi resmi telah dikirim ke ${_emailController.text}.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Reset form kembali bersih:
                _formKey.currentState!.reset();
                _namaController.clear();
                _emailController.clear();
                _pinController.clear();
                _nominalController.clear();
                setState(() {
                  _metodeKurirDipilih = 'Pilih Pengiriman';
                  _tanggalPengiriman = null;
                  _metodePembayaran = null;
                  _setujuSyarat = false;
                });
              },
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4. Proteksi PopScope Android 14+ / Predictive Back
    return PopScope(
      canPop: !_isFormDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool yakin = await _konfirmasiKeluar();
        if (yakin && context.mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            SystemNavigator.pop(); // Menutup layar/aplikasi dengan aman jika merupakan layar root
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout Super App 2026', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0D9488),
          foregroundColor: Colors.white,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informasi Pemesan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),

                // 1. Nama Lengkap
                TextFormField(
                  controller: _namaController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _tandaiFormKotor(),
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Penerima',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Nama wajib diisi!';
                    if (val.trim().length < 3) return 'Nama minimal 3 huruf!';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Email Penerima
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => _tandaiFormKotor(),
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_pinFocus),
                  decoration: const InputDecoration(
                    labelText: 'Alamat Email Notifikasi',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Email wajib diisi!';
                    if (!val.contains('@') || !val.contains('.')) return 'Format email tidak valid!';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 3. PIN / Sandi Keamanan Transaksi (dengan Eye Toggle!)
                TextFormField(
                  controller: _pinController,
                  focusNode: _pinFocus,
                  textInputAction: TextInputAction.next,
                  obscureText: _sembunyikanPin,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _tandaiFormKotor(),
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nominalFocus),
                  decoration: InputDecoration(
                    labelText: 'PIN Transaksi (6 Digit)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_sembunyikanPin ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _sembunyikanPin = !_sembunyikanPin),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'PIN wajib diisi!';
                    if (val.length != 6) return 'PIN harus tepat 6 digit angka!';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. Nominal Pembayaran (Format Rupiah Otomatis)
                TextFormField(
                  controller: _nominalController,
                  focusNode: _nominalFocus,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _tandaiFormKotor(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyRupiahFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Tagihan / Pembayaran',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'Ketik angka, misal: 250000',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi!';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Pemilih Tanggal Pengiriman (showDatePicker)
                InkWell(
                  onTap: _pilihTanggalPengiriman,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, color: Colors.teal),
                            const SizedBox(width: 12),
                            Text(
                              _tanggalPengiriman != null
                                  ? DateFormat('dd MMMM yyyy').format(_tanggalPengiriman!)
                                  : 'Pilih Tanggal Estimasi Pengiriman',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _tanggalPengiriman != null ? FontWeight.bold : FontWeight.normal,
                                color: _tanggalPengiriman != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Opsi Pengiriman (showModalBottomSheet)
                InkWell(
                  onTap: _pilihKurirModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, color: Colors.teal),
                            const SizedBox(width: 12),
                            Text(
                              _metodeKurirDipilih,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _metodeKurirDipilih != 'Pilih Pengiriman' ? FontWeight.bold : FontWeight.normal,
                                color: _metodeKurirDipilih != 'Pilih Pengiriman' ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Dropdown Metode Pembayaran (DropdownButtonFormField)
                DropdownButtonFormField<String>(
                  value: _metodePembayaran,
                  decoration: const InputDecoration(
                    labelText: 'Metode Pembayaran',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'QRIS Instan', child: Text('QRIS (GoPay, OVO, ShopeePay)')),
                    DropdownMenuItem(value: 'Virtual Account BCA', child: Text('BCA Virtual Account')),
                    DropdownMenuItem(value: 'Virtual Account Mandiri', child: Text('Mandiri Virtual Account')),
                    DropdownMenuItem(value: 'Bayar di Tempat (COD)', child: Text('Bayar di Tempat (COD)')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _metodePembayaran = val;
                      _tandaiFormKotor();
                    });
                  },
                  validator: (val) => val == null ? 'Metode pembayaran wajib dipilih!' : null,
                ),
                const SizedBox(height: 12),

                // 8. Checkbox Persetujuan Syarat & Ketentuan (CheckboxListTile)
                CheckboxListTile(
                  value: _setujuSyarat,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Saya menyetujui Syarat & Ketentuan Transaksi TokoKita 2026',
                    style: TextStyle(fontSize: 13),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _setujuSyarat = val ?? false;
                      _tandaiFormKotor();
                    });
                  },
                ),
                const SizedBox(height: 20),

                // 9. Tombol Konfirmasi Transaksi
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _simpanTransaksi,
                    icon: const Icon(Icons.payment),
                    label: const Text('Konfirmasi & Bayar Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}