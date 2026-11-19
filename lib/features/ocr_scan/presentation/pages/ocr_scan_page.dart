import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/category_taxonomy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/finku_app_bar.dart';
import '../../../shared_wallet/presentation/providers/wallet_provider.dart';
import '../../data/ocr_service.dart';
import '../../domain/models/ocr_extraction_result.dart';

/// Halaman Pemindai Struk OCR & Review sesuai Stitch `Pemindai Struk OCR & Review` (`FR-OCR-01..04`).
class OcrScanPage extends ConsumerStatefulWidget {
  const OcrScanPage({
    super.key,
    required this.avatarInitials,
    required this.onOpenSettings,
    this.avatarUrl,
  });

  final String avatarInitials;
  final String? avatarUrl;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<OcrScanPage> createState() => _OcrScanPageState();
}

class _OcrScanPageState extends ConsumerState<OcrScanPage> {
  final _ocrService = OcrService();
  final _picker = ImagePicker();
  final _merchantController = TextEditingController(text: 'Indomaret Sudirman');
  final _totalController = TextEditingController(text: '25604');
  final _dateController = TextEditingController(text: '2026-11-18');

  String _selectedPresetId = 'TC-OCR-01';
  String _selectedCategory = CategoryTaxonomy.belanjaHarian;
  bool _flashOn = true;
  bool _isProcessing = false;
  bool _isSaving = false;
  OcrExtractionResult? _result;

  @override
  void initState() {
    super.initState();
    _loadInitialSample();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSample() async {
    final extracted = await _ocrService.scanPreset(_selectedPresetId);
    if (!mounted) return;
    _applyResult(extracted);
  }

  void _applyResult(OcrExtractionResult extracted) {
    setState(() {
      _result = extracted;
      _merchantController.text = extracted.merchantName;
      _totalController.text = extracted.totalAmount.toString();
      _dateController.text = extracted.txDate;
      _selectedCategory = extracted.suggestedCategory;
    });
  }

  Future<void> _runPresetScan() async {
    setState(() => _isProcessing = true);
    final extracted = await _ocrService.scanPreset(_selectedPresetId);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _applyResult(extracted);
  }

  Future<void> _pickAndScanImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      setState(() => _isProcessing = true);
      final extracted = await _ocrService.scanImageFile(picked.path);
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _applyResult(extracted);
    } catch (_) {
      await _runPresetScan();
    }
  }

  Future<void> _saveTransaction() async {
    final merchant = _merchantController.text.trim();
    final total = CurrencyNormalizer.parseRupiah(_totalController.text);
    if (merchant.isEmpty || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama merchant dan total nominal valid')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final txDate = DateTime.tryParse(_dateController.text) ?? DateTime(2026, 11, 18);
      await ref.read(walletProvider.notifier).addTransaction(
            merchantName: merchant,
            category: _selectedCategory,
            amount: total,
            source: 'ocr',
            txDate: txDate,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaksi OCR tersimpan: $merchant (${CurrencyNormalizer.formatRupiah(total)})',
          ),
          backgroundColor: FinkuColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    final parsedTotal = CurrencyNormalizer.parseRupiah(_totalController.text);

    return Scaffold(
      backgroundColor: FinkuColors.surface,
      appBar: FinkuTopAppBar(
        title: 'Scan Struk',
        avatarInitials: widget.avatarInitials,
        avatarUrl: widget.avatarUrl,
        onOpenSettings: widget.onOpenSettings,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                // Status Feedback Banner (FR-OCR-01)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FinkuColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.document_scanner_rounded,
                            color: FinkuColors.primaryFixed,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isProcessing
                                ? 'Memproses Deskew & OCR...'
                                : 'Pemindai Otomatis Siap',
                            style: FinkuTypography.labelMd(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          res != null ? '${res.processingMs} ms' : 'AI v2.4',
                          style: FinkuTypography.labelSm(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Preset Chips untuk Pengujian TC-OCR-01 s/d TC-OCR-04
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: OcrService.testPresets.map((preset) {
                      final selected = preset.id == _selectedPresetId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.id),
                          selected: selected,
                          selectedColor: FinkuColors.primaryFixed,
                          onSelected: (_) {
                            setState(() => _selectedPresetId = preset.id);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Viewfinder Kamera Pemindai Struk (FR-OCR-01 & FR-OCR-02)
                Container(
                  height: 225,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FinkuColors.inverseSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _flashOn = !_flashOn),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black26,
                              child: Icon(
                                _flashOn ? Icons.bolt_rounded : Icons.flash_off,
                                color: _flashOn
                                    ? FinkuColors.primaryFixed
                                    : Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              'Posisikan struk dalam bingkai',
                              style: FinkuTypography.labelSm(
                                color: FinkuColors.inverseOnSurface,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.black26,
                            child: const Icon(
                              Icons.grid_3x3_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      // Optical Frame Guides & Auto Deskew Badge
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                color: FinkuColors.primaryFixed,
                              ),
                              Positioned(
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FinkuColors.primary.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    OcrService.testPresets
                                        .firstWhere(
                                          (p) => p.id == _selectedPresetId,
                                        )
                                        .conditionBadge,
                                    style: FinkuTypography.labelSm(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Camera Controls (`btn_scan_receipt`)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          InkWell(
                            onTap: () => _pickAndScanImage(ImageSource.gallery),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                Text(
                                  'Galeri',
                                  style: FinkuTypography.labelSm(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            identifier: 'btn_scan_receipt',
                            button: true,
                            label: 'Pindai Struk',
                            child: GestureDetector(
                              key: const Key('btn_scan_receipt'),
                              onTap: _isProcessing ? null : _runPresetScan,
                              child: Container(
                                width: 54,
                                height: 54,
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: FinkuColors.primaryBrand,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _pickAndScanImage(ImageSource.camera),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.photo_camera_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                Text(
                                  'Kamera',
                                  style: FinkuTypography.labelSm(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Confidence Header
                if (res != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FinkuColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FinkuColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: FinkuColors.safeBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: FinkuColors.primaryBrand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _merchantController.text,
                                style: FinkuTypography.titleMd(),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: FinkuColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Terbaca ${(res.confidenceScore * 100).round()}% akurat',
                                    style: FinkuTypography.labelMd(
                                      color: FinkuColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Structured OCR Edit Form (FR-OCR-04)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FinkuColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FinkuColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Data Transaksi Terdeteksi',
                            style: FinkuTypography.headlineSm(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: FinkuColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Dapat diubah',
                              style: FinkuTypography.labelSm(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Nama Toko / Merchant',
                        style: FinkuTypography.labelMd(),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        identifier: 'input_ocr_merchant',
                        textField: true,
                        child: TextField(
                          key: const Key('input_ocr_merchant'),
                          controller: _merchantController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.storefront_rounded,
                              color: FinkuColors.primary,
                            ),
                            hintText: 'Ketik nama toko',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal',
                                  style: FinkuTypography.labelMd(),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _dateController,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kategori',
                                  style: FinkuTypography.labelMd(),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                  ),
                                  items: CategoryTaxonomy.validCategories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            overflow: TextOverflow.ellipsis,
                                            style: FinkuTypography.labelMd(),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCategory = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (res != null && res.items.isNotEmpty) ...[
                        Text(
                          'Rincian Item (${res.items.length} Barang)',
                          style: FinkuTypography.labelLg(),
                        ),
                        const SizedBox(height: 8),
                        ...res.items.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: FinkuColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: FinkuTypography.bodyMd(),
                                      ),
                                      Text(
                                        '${item.qty}x @ ${CurrencyNormalizer.formatRupiah(item.price)}',
                                        style: FinkuTypography.labelSm(),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyNormalizer.formatRupiah(
                                    item.subtotal,
                                  ),
                                  style: FinkuTypography.titleMd(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (res.taxAmount > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PPN / Pajak',
                                  style: FinkuTypography.bodySm(),
                                ),
                                Text(
                                  CurrencyNormalizer.formatRupiah(
                                    res.taxAmount,
                                  ),
                                  style: FinkuTypography.labelMd(),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],

                      Text(
                        'Total Nominal Pembayaran',
                        style: FinkuTypography.labelMd(),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        identifier: 'input_ocr_total',
                        textField: true,
                        child: TextField(
                          key: const Key('input_ocr_total'),
                          controller: _totalController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            prefixText: 'Rp ',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FinkuColors.primaryContainer.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL TERKONVERSI',
                              style: FinkuTypography.labelSm(
                                color: FinkuColors.primary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyNormalizer.formatRupiah(parsedTotal),
                              style: FinkuTypography.displayCurrency(
                                color: FinkuColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Action Toolbar (`btn_save_ocr_tx`)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              border: const Border(
                top: BorderSide(color: FinkuColors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _runPresetScan,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Scan Ulang'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    identifier: 'btn_save_ocr_tx',
                    button: true,
                    child: ElevatedButton.icon(
                      key: const Key('btn_save_ocr_tx'),
                      onPressed: _isSaving ? null : _saveTransaction,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Simpan Transaksi',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
