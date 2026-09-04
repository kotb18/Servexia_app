import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:maintenance/Store/store_service.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';
import 'package:maintenance/imageControl/mobile_image.dart';

// ============================================================================
// 📦 بيانات الألوان والمقاسات المتاحة
// ============================================================================

final List<Map<String, dynamic>> _availableColors = [
  {'name': 'أبيض', 'value': 'white', 'color': Colors.white, 'border': true},
  {'name': 'أسود', 'value': 'black', 'color': Colors.black87},
  {'name': 'رمادي', 'value': 'gray', 'color': Colors.grey},
  {'name': 'أحمر', 'value': 'red', 'color': Colors.red},
  {'name': 'أزرق', 'value': 'blue', 'color': Colors.blue},
  {'name': 'أخضر', 'value': 'green', 'color': Colors.green},
  {'name': 'أصفر', 'value': 'yellow', 'color': Colors.amber},
  {'name': 'برتقالي', 'value': 'orange', 'color': Colors.orange},
  {'name': 'بنفسجي', 'value': 'purple', 'color': Colors.purple},
  {'name': 'وردي', 'value': 'pink', 'color': Colors.pink},
  {'name': 'بني', 'value': 'brown', 'color': Colors.brown},
  {'name': 'بيج', 'value': 'beige', 'color': Color(0xFFF5F5DC)},
  {'name': 'ذهبي', 'value': 'gold', 'color': Color(0xFFFFD700)},
  {'name': 'فضي', 'value': 'silver', 'color': Color(0xFFC0C0C0)},
];

final List<String> _availableSizes = [
  'XS',
  'S',
  'M',
  'L',
  'XL',
  '2XL',
  '3XL',
  '4XL',
  '28',
  '30',
  '32',
  '34',
  '36',
  '38',
  '40',
  '42',
  '44',
  '46',
  '50',
  '52',
  '54',
  '56',
  '58',
  '60',
  'newborn',
  '0-3M',
  '3-6M',
  '6-9M',
  '9-12M',
  '12-18M',
  '18-24M',
  '2T',
  '3T',
  '4T',
  '5T',
  '35',
  '36',
  '37',
  '38',
  '39',
  '40',
  '41',
  '42',
  '43',
  '44',
  '45',
  '46',
];

// ============================================================================
// 🏠 الشاشة الرئيسية
// ============================================================================

class SelectProductsScreen extends StatefulWidget {
  final String groupId;

  const SelectProductsScreen({super.key, required this.groupId});

  @override
  State<SelectProductsScreen> createState() => _SelectProductsScreenState();
}

class _SelectProductsScreenState extends State<SelectProductsScreen> {
  final _service = InventoryStoreService();
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _priceControllers = <String, TextEditingController>{};
  final _descControllers = <String, TextEditingController>{};
  final Map<String, List<String>> _tempImages = {};
  final Set<String> _selectedItems = {};
  final Set<String> _modifiedItems = {};
  bool _isClothes = false; // <-- علم الملابس

  // 🎨 تخزين الألوان والمقاسات المختارة لكل منتج
  final Map<String, Set<String>> _selectedColors = {};
  final Map<String, Set<String>> _selectedSizes = {};

  // 🚩 Flag: هل تم تحميل البيانات الأولية من Firestore؟
  bool _initialDataLoaded = false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _shownInStoreHeader = false;
  bool _shownStockHeader = false;

  final ValueNotifier<int> _changesCountNotifier = ValueNotifier(0);

  @override
  void dispose() {
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    for (var c in _descControllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    _changesCountNotifier.dispose();
    super.dispose();
  }

  void _updateChangesCount() {
    _changesCountNotifier.value =
        _selectedItems.length +
        _modifiedItems.length +
        _selectedColors.values.where((s) => s.isNotEmpty).length +
        _selectedSizes.values.where((s) => s.isNotEmpty).length;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔑 دالة مهمة: تحميل الألوان والمقاسات من Firestore لما الصفحة تفتح
  // ═══════════════════════════════════════════════════════════════════════════
  void _loadExistingStoreData(List<InventoryItemModel> items) {
    for (final item in items) {
      if (item.isInStore) {
        // ✅ لو المنتج موجود في المتجر، نملأ البيانات المحفوظة
        if (item.colors != null && item.colors!.isNotEmpty) {
          _selectedColors[item.sku] = Set<String>.from(item.colors!);
        }
        if (item.sizes != null && item.sizes!.isNotEmpty) {
          _selectedSizes[item.sku] = Set<String>.from(item.sizes!);
        }

        // نملأ الـ Controllers كمان لو فاضيين
        _priceControllers.putIfAbsent(
          item.sku,
          () => TextEditingController(
            text:
                item.storePrice?.toStringAsFixed(2) ??
                item.price.toStringAsFixed(2),
          ),
        );
        _descControllers.putIfAbsent(
          item.sku,
          () => TextEditingController(text: item.storeDescription ?? ''),
        );
      }
    }

    _initialDataLoaded = true;
    _updateChangesCount();
  }

  // ========== الصور ==========

  Future<void> _pickImages(String sku) async {
    final pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedFiles.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final compressedImages = await Future.wait(
        pickedFiles.map((file) => _compressAndUploadImage(file, sku)),
      );

      setState(() {
        _tempImages[sku] ??= [];
        _tempImages[sku]!.addAll(
          compressedImages.where((url) => url != null).cast<String>(),
        );
        _modifiedItems.add(sku);
        _updateChangesCount();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الصور: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════
  // 🗜️ ضغط الصورة ورفعها لـ Firebase Storage
  // ✅ يعمل على الموبايل + الويب (بدون path_provider)
  // ═══════════════════════════════════════════════════
  Future<String?> _compressAndUploadImage(XFile file, String sku) async {
    // قراءة الصورة كـ bytes (يعمل على موبايل + ويب)
    final imageBytes = await file.readAsBytes();

    // ضغط الصورة (يعمل على كل المنصات)
    final compressedBytes = await FlutterImageCompress.compressWithList(
      imageBytes,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes.isEmpty) return null;

    final ref = _storage
        .ref()
        .child('stores')
        .child(widget.groupId)
        .child(sku)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    // ✅ putData بدل putFile — شغالة على المنصتين
    await ref.putData(
      Uint8List.fromList(compressedBytes),
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }

  void _removeImage(String sku, String imageUrl) {
    setState(() {
      _tempImages[sku]?.remove(imageUrl);
      if (_tempImages[sku]?.isEmpty ?? false) {
        _tempImages.remove(sku);
      }
      _modifiedItems.add(sku);
      _updateChangesCount();
    });
  }

  // ========== الحفظ ==========

  Future<void> _saveSelection() async {
    setState(() => _isLoading = true);

    int addedCount = 0;
    int updatedCount = 0;

    try {
      final itemsToSave = {..._selectedItems, ..._modifiedItems};

      for (final sku in itemsToSave) {
        final priceText = _priceControllers[sku]?.text ?? '';
        final price = double.tryParse(priceText);

        if (price == null || price <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('السعر غير صالح للمنتج: $sku'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          continue;
        }

        final desc = _descControllers[sku]?.text.trim();
        final images = _tempImages[sku];
        final colors = _selectedColors[sku]?.toList();
        final sizes = _selectedSizes[sku]?.toList();

        final item = await _service.getItemBySku(widget.groupId, sku);
        if (item == null) continue;

        if (item.isInStore) {
          await _service.updateStoreProduct(
            groupId: widget.groupId,
            sku: sku,
            storePrice: price,
            storeDescription: desc,
            images: images,
            colors: colors,
            sizes: sizes,
          );
          updatedCount++;
        } else {
          await _service.addToStore(
            groupId: widget.groupId,
            sku: sku,
            storePrice: price,
            storeDescription: desc,
            images: images,
            colors: colors,
            sizes: sizes,
          );
          addedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم: $addedCount إضافة جديدة، $updatedCount تحديث'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ========== الإزالة ==========

  Future<void> _confirmRemoveFromStore(InventoryItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('إزالة من المتجر'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من إزالة "${item.name}" من المتجر الإلكتروني؟\n\n'
          '⚠️ سيتم حذف الصور والسعر الخاص بالمتجر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('إزالة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _deleteStoreImages(widget.groupId, item.sku);
        await _service.removeFromStore(widget.groupId, item.sku);

        _priceControllers.remove(item.sku)?.dispose();
        _descControllers.remove(item.sku)?.dispose();
        _tempImages.remove(item.sku);
        _selectedItems.remove(item.sku);
        _modifiedItems.remove(item.sku);
        _selectedColors.remove(item.sku);
        _selectedSizes.remove(item.sku);
        _updateChangesCount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ تمت الإزالة من المتجر'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteStoreImages(String groupId, String sku) async {
    try {
      final listResult = await _storage
          .ref()
          .child('stores')
          .child(groupId)
          .child(sku)
          .listAll();

      await Future.wait(listResult.items.map((ref) => ref.delete()));
    } catch (e) {
      debugPrint('No images to delete: $e');
    }
  }

  Future<void> getStoreData() async {
    final storeService = StoreService();
    final store = await storeService.getStoreById(widget.groupId);
    if (store != null) {
      setState(() {
        _isClothes = store.isClothes;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getStoreData();
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'اختيار منتجات المتجر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _changesCountNotifier,
            builder: (context, count, child) {
              if (count > 0) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _shownInStoreHeader = false;
                  _shownStockHeader = false;
                });
              },
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الكود...',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _shownInStoreHeader = false;
                            _shownStockHeader = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: FirestorePagination(
              key: ValueKey('inventory-pagination-$_searchQuery'),
              limit: 6,
              isLive: true,
              viewType: ViewType.list,
              padding: const EdgeInsets.all(16),
              query: _service.getAllItemsQuery(widget.groupId),
              bottomLoader: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              onEmpty: _searchQuery.isEmpty
                  ? _buildEmptyWidget()
                  : _buildNoSearchResults(),
              itemBuilder: (context, documentSnapshots, index) {
                final documentSnapshot = documentSnapshots[index];
                final item = InventoryItemModel.fromFirestore(documentSnapshot);

                if (!_initialDataLoaded || item.isInStore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _loadExistingStoreData([item]);
                    if (!_initialDataLoaded) {
                      setState(() => _initialDataLoaded = true);
                    }
                  });
                }

                final query = _searchQuery.trim().toLowerCase();
                final matchesSearch =
                    query.isEmpty ||
                    item.name.toLowerCase().contains(query) ||
                    item.sku.toLowerCase().contains(query);

                if (!matchesSearch) return const SizedBox.shrink();

                Widget card = _buildItemCard(
                  item,
                  isAlreadyInStore: item.isInStore,
                );

                if (item.isInStore && !_shownInStoreHeader) {
                  _shownInStoreHeader = true;
                  card = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        '✅ منتجات في المتجر',
                        '',
                        Colors.green,
                      ),
                      card,
                    ],
                  );
                } else if (!item.isInStore && !_shownStockHeader) {
                  _shownStockHeader = true;
                  card = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('📦 أصناف المخزون', '', Colors.blue),
                      card,
                    ],
                  );
                }

                return card;
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _changesCountNotifier,
        builder: (context, count, child) {
          return _buildSaveButton(theme, count > 0);
        },
      ),
    );
  }

  Widget _buildItemCard(
    InventoryItemModel item, {
    required bool isAlreadyInStore,
  }) {
    return _ItemCardWidget(
      key: ValueKey('${item.sku}_${_initialDataLoaded}'),
      item: item,
      isAlreadyInStore: isAlreadyInStore,
      priceControllers: _priceControllers,
      descControllers: _descControllers,
      tempImages: _tempImages,
      selectedItems: _selectedItems,
      modifiedItems: _modifiedItems,
      selectedColors: _selectedColors,
      selectedSizes: _selectedSizes,
      isClothes: _isClothes,
      onToggleAddSelection: (sku) {
        setState(() {
          if (_selectedItems.contains(sku)) {
            _selectedItems.remove(sku);
            _tempImages.remove(sku);
            _selectedColors.remove(sku);
            _selectedSizes.remove(sku);
          } else {
            _selectedItems.add(sku);
          }
          _updateChangesCount();
        });
      },
      onRemoveImage: _removeImage,
      onConfirmRemoveFromStore: _confirmRemoveFromStore,
      onNotifyChange: _updateChangesCount,
      pickImages: _pickImages,
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد أصناف في المخزون',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف أصنافاً أولاً من شاشة المخزون',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج لـ "$_searchQuery"',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme, bool hasChanges) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: hasChanges
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: hasChanges && !_isLoading ? _saveSelection : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isLoading
                  ? 'جاري الحفظ...'
                  : hasChanges
                  ? 'حفظ التغييرات (${_selectedItems.length + _modifiedItems.length})'
                  : 'لا توجد تغييرات',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasChanges
                  ? theme.primaryColor
                  : Colors.grey.shade300,
              foregroundColor: hasChanges ? Colors.white : Colors.grey.shade600,
              elevation: hasChanges ? 4 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🃏 ويدجت الكارت لكل منتج
// ============================================================================

class _ItemCardWidget extends StatefulWidget {
  final InventoryItemModel item;
  final bool isAlreadyInStore;
  final Map<String, TextEditingController> priceControllers;
  final Map<String, TextEditingController> descControllers;
  final Map<String, List<String>> tempImages;
  final Set<String> selectedItems;
  final Set<String> modifiedItems;
  final Map<String, Set<String>> selectedColors;
  final Map<String, Set<String>> selectedSizes;
  final Function(String) onToggleAddSelection;
  final Function(String, String) onRemoveImage;
  final Function(InventoryItemModel) onConfirmRemoveFromStore;
  final VoidCallback onNotifyChange;
  final Function(String) pickImages;
  final bool isClothes;

  const _ItemCardWidget({
    Key? key,
    required this.item,
    required this.isAlreadyInStore,
    required this.priceControllers,
    required this.descControllers,
    required this.tempImages,
    required this.selectedItems,
    required this.modifiedItems,
    required this.selectedColors,
    required this.selectedSizes,
    required this.onToggleAddSelection,
    required this.onRemoveImage,
    required this.onConfirmRemoveFromStore,
    required this.onNotifyChange,
    required this.pickImages,
    required this.isClothes,
  }) : super(key: key);

  @override
  State<_ItemCardWidget> createState() => _ItemCardWidgetState();
}

class _ItemCardWidgetState extends State<_ItemCardWidget> {
  late TextEditingController _priceController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _priceController = widget.priceControllers.putIfAbsent(
      widget.item.sku,
      () => TextEditingController(
        text:
            widget.item.storePrice?.toStringAsFixed(2) ??
            widget.item.price.toStringAsFixed(2),
      ),
    );
    _descController = widget.descControllers.putIfAbsent(
      widget.item.sku,
      () => TextEditingController(text: widget.item.storeDescription ?? ''),
    );

    _priceController.addListener(_handleTextChange);
    _descController.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    widget.modifiedItems.add(widget.item.sku);
    widget.onNotifyChange();
  }

  @override
  void dispose() {
    _priceController.removeListener(_handleTextChange);
    _descController.removeListener(_handleTextChange);
    super.dispose();
  }

  void _toggleColor(String colorValue) {
    setState(() {
      final colors = widget.selectedColors.putIfAbsent(
        widget.item.sku,
        () => <String>{},
      );
      if (colors.contains(colorValue)) {
        colors.remove(colorValue);
      } else {
        colors.add(colorValue);
      }
      widget.modifiedItems.add(widget.item.sku);
      widget.onNotifyChange();
    });
  }

  void _toggleSize(String sizeValue) {
    setState(() {
      final sizes = widget.selectedSizes.putIfAbsent(
        widget.item.sku,
        () => <String>{},
      );
      if (sizes.contains(sizeValue)) {
        sizes.remove(sizeValue);
      } else {
        sizes.add(sizeValue);
      }
      widget.modifiedItems.add(widget.item.sku);
      widget.onNotifyChange();
    });
  }

  void _showColorPicker() {
    final currentColors = widget.selectedColors[widget.item.sku] ?? <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.palette, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        'اختيار الألوان المتاحة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            widget.selectedColors[widget.item.sku]?.clear();
                          });
                          setState(() {});
                          widget.modifiedItems.add(widget.item.sku);
                          widget.onNotifyChange();
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('مسح الكل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availableColors.map((colorData) {
                          final value = colorData['value'] as String;
                          final name = colorData['name'] as String;
                          final color = colorData['color'] as Color;
                          final hasBorder = colorData['border'] == true;
                          final isSelected = currentColors.contains(value);

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (currentColors.contains(value)) {
                                  currentColors.remove(value);
                                } else {
                                  currentColors.add(value);
                                }
                              });
                              _toggleColor(value);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.2)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? color == Colors.white
                                            ? Colors.deepPurple
                                            : color
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: hasBorder
                                          ? Border.all(
                                              color: Colors.grey.shade400,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: Colors.deepPurple,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check),
                      label: Text('تم اختيار ${currentColors.length} لون'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSizePicker() {
    final currentSizes = widget.selectedSizes[widget.item.sku] ?? <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.straighten, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      const Text(
                        'اختيار المقاسات المتاحة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            widget.selectedSizes[widget.item.sku]?.clear();
                          });
                          setState(() {});
                          widget.modifiedItems.add(widget.item.sku);
                          widget.onNotifyChange();
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('مسح الكل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availableSizes.map((size) {
                          final isSelected = currentSizes.contains(size);

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (currentSizes.contains(size)) {
                                  currentSizes.remove(size);
                                } else {
                                  currentSizes.add(size);
                                }
                              });
                              _toggleSize(size);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepOrange
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.deepOrange
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                size,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check),
                      label: Text('تم اختيار ${currentSizes.length} مقاس'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedItems.contains(widget.item.sku);
    final isModified = widget.modifiedItems.contains(widget.item.sku);
    final showDetails = isSelected || widget.isAlreadyInStore;

    final currentImages =
        widget.tempImages[widget.item.sku] ??
        List<String>.from(widget.item.imagesList);

    final currentColors = widget.selectedColors[widget.item.sku] ?? <String>{};
    final currentSizes = widget.selectedSizes[widget.item.sku] ?? <String>{};

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isAlreadyInStore
            ? Colors.green.shade50
            : isSelected
            ? Colors.blue.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isAlreadyInStore
              ? Colors.green
              : isSelected
              ? Colors.blue
              : isModified
              ? Colors.orange
              : Colors.grey.shade200,
          width: isSelected || widget.isAlreadyInStore || isModified ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.isAlreadyInStore
                ? null
                : () {
                    widget.onToggleAddSelection(widget.item.sku);
                  },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.isAlreadyInStore
                          ? Colors.green
                          : isSelected
                          ? Colors.red
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: widget.isAlreadyInStore || isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade400),
                    ),
                    child: widget.isAlreadyInStore
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  _buildItemImage(widget.item),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'كود: ${widget.item.sku}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.item.quantity} ${widget.item.unit}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.attach_money_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            Text(
                              'تكلفة: ${widget.item.coast.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (widget.item.isInStore &&
                            widget.item.storePrice != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'سعر المتجر: ${widget.item.storePrice!.toStringAsFixed(2)} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDetails)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: widget.isAlreadyInStore
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildPriceField(widget.item),
                  const SizedBox(height: 12),
                  _buildDescriptionField(widget.item),
                  const SizedBox(height: 16),
                  if (widget.isClothes)
                    _buildColorsAndSizesSection(currentColors, currentSizes),
                  const SizedBox(height: 16),
                  _buildImagesSection(
                    widget.item.sku,
                    widget.item,
                    currentImages,
                  ),
                  const SizedBox(height: 16),
                  if (widget.isAlreadyInStore)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            widget.onConfirmRemoveFromStore(widget.item),
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'إزالة من المتجر',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Widget _buildColorsAndSizesSection(
    Set<String> currentColors,
    Set<String> currentSizes,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_paint_outlined,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'خيارات المنتج (اختياري)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (currentColors.isNotEmpty || currentSizes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentColors.length} لون · ${currentSizes.length} مقاس',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildColorPreviewRow(currentColors),
          const SizedBox(height: 10),
          _buildSizePreviewRow(currentSizes),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showColorPicker,
                  icon: const Icon(
                    Icons.palette_outlined,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  label: Text(
                    currentColors.isEmpty ? 'اختيار الألوان' : 'تعديل الألوان',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSizePicker,
                  icon: const Icon(
                    Icons.straighten,
                    size: 18,
                    color: Colors.deepOrange,
                  ),
                  label: Text(
                    currentSizes.isEmpty ? 'اختيار المقاسات' : 'تعديل المقاسات',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPreviewRow(Set<String> currentColors) {
    if (currentColors.isEmpty) {
      return Text(
        'لم يتم اختيار ألوان',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: currentColors.map((colorValue) {
        final colorData = _availableColors.firstWhere(
          (c) => c['value'] == colorValue,
          orElse: () => {'name': colorValue, 'color': Colors.grey},
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (colorData['color'] as Color).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (colorData['color'] as Color).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colorData['color'] as Color,
                  shape: BoxShape.circle,
                  border: colorData['border'] == true
                      ? Border.all(color: Colors.grey.shade400, width: 1)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                colorData['name'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _toggleColor(colorValue),
                child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizePreviewRow(Set<String> currentSizes) {
    if (currentSizes.isEmpty) {
      return Text(
        'لم يتم اختيار مقاسات',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: currentSizes.map((size) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                size,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _toggleSize(size),
                child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceField(InventoryItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: const Text(
              'سعر البيع:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: item.price.toStringAsFixed(2),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField(InventoryItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _descController,
        maxLines: 3,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'وصف تسويقي للمتجر (اختياري)...',
          hintTextDirection: TextDirection.rtl,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildImagesSection(
    String sku,
    InventoryItemModel item,
    List<String> currentImages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'صور المنتج في المتجر',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (currentImages.isNotEmpty)
              Text(
                '${currentImages.length} صورة',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (currentImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: currentImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: currentImages.isNotEmpty
                            ? WebImage(
                                src: currentImages[index],
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : _buildPlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: InkWell(
                        onTap: () =>
                            widget.onRemoveImage(sku, currentImages[index]),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => widget.pickImages(sku),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إضافة صور'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemImage(InventoryItemModel item) {
    if (item.imagesList.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          item.imagesList.first,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image, color: Colors.grey.shade300, size: 32),
    );
  }
}
