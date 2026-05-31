import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:maintenance/Store/inventory_item_model.dart';
import 'package:maintenance/Store/inventory_store_service.dart';

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
  final Set<String> _modifiedItems = {}; // <-- جديد: منتجات تم تعديلها

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    for (var c in _descControllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
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
        // علّم المنتج كمُعدّل
        _modifiedItems.add(sku);
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

  Future<String?> _compressAndUploadImage(XFile file, String sku) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) return null;

    final ref = _storage
        .ref()
        .child('stores')
        .child(widget.groupId)
        .child(sku)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(File(compressed.path));
    return await ref.getDownloadURL();
  }

  void _removeImage(String sku, String imageUrl) {
    setState(() {
      _tempImages[sku]?.remove(imageUrl);
      if (_tempImages[sku]?.isEmpty ?? false) {
        _tempImages.remove(sku);
      }
      _modifiedItems.add(sku);
    });
  }

  // ========== الحفظ ==========

  Future<void> _saveSelection() async {
    setState(() => _isLoading = true);

    int addedCount = 0;
    int updatedCount = 0;

    try {
      // اجمع كل المنتجات اللي لازم تحفظ (مختارة + مُعدّلة)
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

        final item = await _service.getItemBySku(widget.groupId, sku);
        if (item == null) continue;

        if (item.isInStore) {
          // تحديث منتج موجود
          await _service.updateStoreProduct(
            groupId: widget.groupId,
            sku: sku,
            storePrice: price,
            storeDescription: desc,
            images: images,
          );
          updatedCount++;
        } else {
          // إضافة منتج جديد
          await _service.addToStore(
            groupId: widget.groupId,
            sku: sku,
            storePrice: price,
            storeDescription: desc,
            images: images,
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
        // ارجع للخلف بعد نجاح الحفظ
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

        // نظف الـ controllers
        _priceControllers.remove(item.sku)?.dispose();
        _descControllers.remove(item.sku)?.dispose();
        _tempImages.remove(item.sku);
        _selectedItems.remove(item.sku);
        _modifiedItems.remove(item.sku);

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
          // عدد المنتجات المختارة
          if (_selectedItems.isNotEmpty || _modifiedItems.isNotEmpty)
            Center(
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
                  '${_selectedItems.length + _modifiedItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث المحسّن
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
              onChanged: (value) => setState(() => _searchQuery = value),
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
                          setState(() => _searchQuery = '');
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

          // القائمة
          Expanded(
            child: StreamBuilder<List<InventoryItemModel>>(
              stream: _service.getAllItems(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }

                final allItems = snapshot.data ?? [];

                if (allItems.isEmpty) {
                  return _buildEmptyWidget();
                }

                // فلترة البحث
                final items = _searchQuery.isEmpty
                    ? allItems
                    : allItems.where((item) {
                        final query = _searchQuery.toLowerCase();
                        return item.name.toLowerCase().contains(query) ||
                            item.sku.toLowerCase().contains(query);
                      }).toList();

                final inStoreItems = items.where((i) => i.isInStore).toList();
                final notInStoreItems = items
                    .where((i) => !i.isInStore)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // الأصناف المُفعلة
                    if (inStoreItems.isNotEmpty) ...[
                      _buildSectionHeader(
                        '✅ منتجات في المتجر',
                        '${inStoreItems.length} منتج',
                        Colors.green,
                      ),
                      ...inStoreItems.map(
                        (item) => _buildItemCard(item, isAlreadyInStore: true),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // الأصناف المتاحة
                    if (notInStoreItems.isNotEmpty) ...[
                      _buildSectionHeader(
                        '📦 أصناف المخزون',
                        '${notInStoreItems.length} متاح',
                        Colors.blue,
                      ),
                      ...notInStoreItems.map(
                        (item) => _buildItemCard(item, isAlreadyInStore: false),
                      ),
                    ],

                    if (items.isEmpty) _buildNoSearchResults(),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // زر الحفظ السفلي المحسّن
      bottomNavigationBar: _buildSaveButton(theme),
    );
  }

  // ========== ويدجتس مساعدة ==========

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
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

  Widget _buildSaveButton(ThemeData theme) {
    final hasChanges = _selectedItems.isNotEmpty || _modifiedItems.isNotEmpty;

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

  // ========== كارت المنتج ==========

  Widget _buildItemCard(
    InventoryItemModel item, {
    required bool isAlreadyInStore,
  }) {
    final isSelected = _selectedItems.contains(item.sku);
    final isModified = _modifiedItems.contains(item.sku);
    final showDetails = isSelected || isAlreadyInStore;

    // تهيئة الـ controllers
    if (!_priceControllers.containsKey(item.sku)) {
      _priceControllers[item.sku] = TextEditingController(
        text:
            item.storePrice?.toStringAsFixed(2) ??
            item.price.toStringAsFixed(2),
      );
    }
    if (!_descControllers.containsKey(item.sku)) {
      _descControllers[item.sku] = TextEditingController(
        text: item.storeDescription ?? '',
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAlreadyInStore
            ? Colors.green.shade50
            : isSelected
            ? Colors.blue.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlreadyInStore
              ? Colors.green
              : isSelected
              ? Colors.blue
              : isModified
              ? Colors.orange
              : Colors.grey.shade200,
          width: isSelected || isAlreadyInStore || isModified ? 2 : 1,
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
          // الصف الرئيسي
          InkWell(
            onTap: isAlreadyInStore
                ? null
                : () => _toggleAddSelection(item.sku),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Checkbox أو أيقونة
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isAlreadyInStore
                          ? Colors.green
                          : isSelected
                          ? Colors.red
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isAlreadyInStore || isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade400),
                    ),
                    child: isAlreadyInStore
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // الصورة
                  _buildItemImage(item),
                  const SizedBox(width: 16),

                  // المعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
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
                            'كود: ${item.sku}',
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
                              '${item.quantity} ${item.unit}',
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
                              'تكلفة: ${item.coast.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (item.isInStore && item.storePrice != null)
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
                              'سعر المتجر: ${item.storePrice!.toStringAsFixed(2)} ج.م',
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

          // التفاصيل القابلة للتوسيع
          if (showDetails)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: isAlreadyInStore
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

                  // السعر
                  _buildPriceField(item),
                  const SizedBox(height: 12),

                  // الوصف
                  _buildDescriptionField(item),
                  const SizedBox(height: 16),

                  // الصور
                  _buildImagesSection(item.sku, item),
                  const SizedBox(height: 16),

                  // زر الإزالة (للمنتجات المُفعلة فقط)
                  if (isAlreadyInStore)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmRemoveFromStore(item),
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
              controller: _priceControllers[item.sku],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: item.price.toStringAsFixed(2),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                suffixText: 'ج.م',
              ),
              onChanged: (_) => setState(() => _modifiedItems.add(item.sku)),
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
        controller: _descControllers[item.sku],
        maxLines: 3,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'وصف تسويقي للمتجر (اختياري)...',
          hintTextDirection: TextDirection.rtl,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (_) => setState(() => _modifiedItems.add(item.sku)),
      ),
    );
  }

  Widget _buildImagesSection(String sku, InventoryItemModel item) {
    final currentImages =
        _tempImages[sku] ?? List<String>.from(item.imagesList);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
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

          // عرض الصور
          if (currentImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: currentImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(currentImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 14,
                        child: InkWell(
                          onTap: () => _removeImage(sku, currentImages[index]),
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

          // زر إضافة صور
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickImages(sku),
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
      ),
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

  void _toggleAddSelection(String sku) {
    setState(() {
      if (_selectedItems.contains(sku)) {
        _selectedItems.remove(sku);
        _tempImages.remove(sku);
      } else {
        _selectedItems.add(sku);
      }
    });
  }
}
