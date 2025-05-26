import 'package:flutter/material.dart';
import '../services/grocery_list_service.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({Key? key}) : super(key: key);

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  List<GroceryItem> groceryItems = [];
  bool isLoading = true;
  final TextEditingController _addItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroceryList();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    super.dispose();
  }

  Future<void> _loadGroceryList() async {
    setState(() => isLoading = true);
    final items = await GroceryListService.getGroceryList();
    setState(() {
      groceryItems = items;
      isLoading = false;
    });
  }

  Future<void> _addItem() async {
    final itemName = _addItemController.text.trim();
    if (itemName.isNotEmpty) {
      await GroceryListService.addToGroceryList(itemName);
      _addItemController.clear();
      await _loadGroceryList();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$itemName" to grocery list'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleItemCompleted(String itemId) async {
    await GroceryListService.toggleItemCompleted(itemId);
    await _loadGroceryList();
  }

  Future<void> _removeItem(String itemId) async {
    await GroceryListService.removeFromGroceryList(itemId);
    await _loadGroceryList();
  }

  Future<void> _clearCompleted() async {
    await GroceryListService.clearCompletedItems();
    await _loadGroceryList();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cleared completed items'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Map<String, IconData> getCategoryIcons() {
    return {
      'Protein': Icons.set_meal,
      'Dairy & Eggs': Icons.egg_alt,
      'Fruits': Icons.apple,
      'Vegetables': Icons.eco,
      'Grains & Bread': Icons.grain,
      'Condiments & Spices': Icons.kitchen,
      'Nuts & Seeds': Icons.scatter_plot,
      'Legumes': Icons.circle,
      'Other': Icons.shopping_basket,
    };
  }

  Map<String, Color> getCategoryColors() {
    return {
      'Protein': Colors.red[300]!,
      'Dairy & Eggs': Colors.yellow[300]!,
      'Fruits': Colors.orange[300]!,
      'Vegetables': Colors.green[300]!,
      'Grains & Bread': Colors.brown[300]!,
      'Condiments & Spices': Colors.purple[300]!,
      'Nuts & Seeds': Colors.amber[300]!,
      'Legumes': Colors.teal[300]!,
      'Other': Colors.grey[300]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final groupedItems = GroceryListService.groupByCategory(groceryItems);
    final completedCount = groceryItems.where((item) => item.isCompleted).length;
    final totalCount = groceryItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Grocery List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (completedCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearCompleted,
              tooltip: 'Clear completed items',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Items'),
                    content: const Text('Are you sure you want to remove all items from your grocery list?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await GroceryListService.clearAllItems();
                  await _loadGroceryList();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (totalCount > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shopping Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '$completedCount/$totalCount items',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: totalCount > 0 ? completedCount / totalCount : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completedCount == totalCount ? Colors.green : Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                ],
              ),
            ),

          // Add new item
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addItemController,
                    decoration: InputDecoration(
                      hintText: 'Add new item...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  onPressed: _addItem,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Grocery list
          Expanded(
            child: groceryItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your grocery list is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add ingredients from recipes or manually',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groupedItems.keys.length,
                    itemBuilder: (context, index) {
                      final category = groupedItems.keys.elementAt(index);
                      final items = groupedItems[category]!;
                      final categoryIcons = getCategoryIcons();
                      final categoryColors = getCategoryColors();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                            // Category header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: categoryColors[category]!.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: categoryColors[category],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      categoryIcons[category],
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: categoryColors[category],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${items.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Category items
                            ...items.map((item) => _buildGroceryItem(item)).toList(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryItem(GroceryItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: item.isCompleted,
            onChanged: (_) => _toggleItemCompleted(item.id),
            activeColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Item name
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 16,
                color: item.isCompleted ? Colors.grey[500] : Colors.black87,
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                fontWeight: item.isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          
          // Remove button
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.grey[400],
              size: 20,
            ),
            onPressed: () => _removeItem(item.id),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}