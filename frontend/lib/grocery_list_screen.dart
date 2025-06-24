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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                    itemCount: groceryItems.length,
                    itemBuilder: (context, index) {
                      final item = groceryItems[index];
                      return _buildGroceryItem(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryItem(GroceryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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