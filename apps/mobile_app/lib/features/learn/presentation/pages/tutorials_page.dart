import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// In-app tutorials and learning page with categorized
/// step-by-step guides for using RBLX Clothing Maker.
class TutorialsPage extends StatefulWidget {
  const TutorialsPage({super.key});

  @override
  State<TutorialsPage> createState() => _TutorialsPageState();
}

class _TutorialsPageState extends State<TutorialsPage> {
  int _selectedLevel = 0;

  static const _levels = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  static const _tutorials = [
    _Tutorial(
      title: 'Create Your First Shirt',
      description: 'Learn the basics of the 2D editor: drawing, filling, and exporting a Roblox shirt template.',
      icon: Icons.checkroom,
      level: 'Beginner',
      duration: '5 min',
      color: Color(0xFF2196F3),
      steps: [
        'Open the Editor and select "Blank Shirt"',
        'Use the Draw tool to sketch your design',
        'Try the Fill tool to add solid colors',
        'Switch between parts (Front, Back, Sleeves)',
        'Preview in 3D by checking the right panel',
        'Export as PNG when done',
      ],
    ),
    _Tutorial(
      title: 'Using Gradient Fills',
      description: 'Master gradient fills to create smooth color transitions on your clothing.',
      icon: Icons.gradient,
      level: 'Beginner',
      duration: '3 min',
      color: Color(0xFFFF6A1A),
      steps: [
        'Select the Gradient tool from the toolbar',
        'Choose your start color from the palette',
        'Select an end color from the gradient controls',
        'Switch between Linear and Radial modes',
        'Tap on the canvas to apply the gradient',
        'Experiment with different color combinations',
      ],
    ),
    _Tutorial(
      title: 'Adding Shapes & Stickers',
      description: 'Learn how to add geometric shapes and emoji stickers to enhance your designs.',
      icon: Icons.crop_square,
      level: 'Beginner',
      duration: '4 min',
      color: Color(0xFF4CAF50),
      steps: [
        'Select the Shape tool from the toolbar',
        'Choose a shape: Rectangle, Circle, Triangle, Star',
        'Drag on canvas to draw the shape',
        'Toggle between Filled and Outline modes',
        'For stickers, tap the Sticker tool',
        'Browse categories and tap to add',
        'Drag stickers to reposition them',
      ],
    ),
    _Tutorial(
      title: 'Working with Layers',
      description: 'Understand blend modes and layer ordering to create professional designs.',
      icon: Icons.layers,
      level: 'Intermediate',
      duration: '6 min',
      color: Color(0xFF9C27B0),
      steps: [
        'Each stroke is a separate layer',
        'Change blend modes: Normal, Multiply, Screen, Overlay',
        'Use Multiply for darkening effects',
        'Use Screen for lightening effects',
        'Overlay combines both for contrast',
        'Adjust opacity with the slider for subtle effects',
      ],
    ),
    _Tutorial(
      title: '2D to 3D Preview',
      description: 'See your designs in real-time on a 3D mannequin as you draw.',
      icon: Icons.view_in_ar,
      level: 'Intermediate',
      duration: '4 min',
      color: Color(0xFFE91E63),
      steps: [
        'The 3D preview panel shows your design live',
        'Draw on the 2D canvas — it syncs automatically',
        'Use the environment buttons to change lighting',
        'Studio, Outdoor, Sunset, and Neon presets available',
        'Take a screenshot with the camera button',
        'Share your 3D renders directly',
      ],
    ),
    _Tutorial(
      title: 'Publishing to Roblox',
      description: 'Upload your finished design directly to Roblox with one click.',
      icon: Icons.cloud_upload,
      level: 'Intermediate',
      duration: '5 min',
      color: Color(0xFF00BCD4),
      steps: [
        'Finish your design in the editor',
        'Tap the Export button in the top bar',
        'Select "Upload to Roblox" in the publish sheet',
        'Link your Roblox account if not already linked',
        'Add a name and description for your asset',
        'Hit Upload — your design goes live on Roblox!',
      ],
    ),
    _Tutorial(
      title: 'AI-Powered Texture Generation',
      description: 'Use AI to generate unique textures and apply them to your designs.',
      icon: Icons.auto_awesome,
      level: 'Advanced',
      duration: '7 min',
      color: Color(0xFFFF5722),
      steps: [
        'Open the AI Generate tool',
        'Type a descriptive prompt (e.g., "galaxy nebula pattern")',
        'Wait for the AI to generate the texture',
        'The texture is applied directly to your canvas',
        'Combine AI textures with manual edits',
        'Use different prompts for each part (Front, Back)',
        'Credits are consumed per generation',
      ],
    ),
    _Tutorial(
      title: 'Element Transforms',
      description: 'Master Copy, Paste, Flip, Rotate, and Opacity controls for precise designs.',
      icon: Icons.transform,
      level: 'Advanced',
      duration: '5 min',
      color: Color(0xFF795548),
      steps: [
        'Tap any element (sticker, image) to select it',
        'A floating toolbar appears with controls',
        'Copy: duplicate the selected element',
        'Paste: place the copy with a slight offset',
        'Flip H/V: mirror the element horizontally/vertically',
        'Rotate: turn 90° clockwise or counter-clockwise',
        'Opacity: use the slider for transparency effects',
        'Delete: remove the selected element',
      ],
    ),
  ];

  List<_Tutorial> get _filteredTutorials {
    if (_selectedLevel == 0) return _tutorials;
    return _tutorials.where((t) => t.level == _levels[_selectedLevel]).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Learn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.outlineVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _levels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isActive = index == _selectedLevel;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLevel = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: isActive
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                            : null,
                      ),
                      child: Text(_levels[index], style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.onSurface,
                      )),
                    ),
                  );
                },
              ),
            ),
          ),

          // Tutorial list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredTutorials.length,
              itemBuilder: (context, index) {
                final tutorial = _filteredTutorials[index];
                return _TutorialCard(
                  tutorial: tutorial,
                  onTap: () => _openTutorial(tutorial),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openTutorial(_Tutorial tutorial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TutorialDetailSheet(tutorial: tutorial),
    );
  }
}

class _Tutorial {
  final String title;
  final String description;
  final IconData icon;
  final String level;
  final String duration;
  final Color color;
  final List<String> steps;

  const _Tutorial({
    required this.title,
    required this.description,
    required this.icon,
    required this.level,
    required this.duration,
    required this.color,
    required this.steps,
  });
}

class _TutorialCard extends StatelessWidget {
  final _Tutorial tutorial;
  final VoidCallback onTap;

  const _TutorialCard({required this.tutorial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: tutorial.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tutorial.icon, color: tutorial.color, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tutorial.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  SizedBox(height: 4),
                  Text(tutorial.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.outlineVariant.withValues(alpha: 0.7))),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      _badge(tutorial.level, tutorial.color),
                      const SizedBox(width: 6),
                      _badge(tutorial.duration, AppColors.outlineVariant),
                      SizedBox(width: 6),
                      _badge('${tutorial.steps.length} steps', AppColors.outlineVariant),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _TutorialDetailSheet extends StatefulWidget {
  final _Tutorial tutorial;

  const _TutorialDetailSheet({required this.tutorial});

  @override
  State<_TutorialDetailSheet> createState() => _TutorialDetailSheetState();
}

class _TutorialDetailSheetState extends State<_TutorialDetailSheet> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.outlineVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.tutorial.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.tutorial.icon, color: widget.tutorial.color, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.tutorial.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(AppLocalizations.of(context)!.tutorialsStepOf(_currentStep + 1, widget.tutorial.steps.length),
                        style: TextStyle(fontSize: 11, color: AppColors.outlineVariant.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 20, color: AppColors.outlineVariant),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / widget.tutorial.steps.length,
                backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(widget.tutorial.color),
                minHeight: 4,
              ),
            ),
          ),
          SizedBox(height: 20),
          // Step content
          Expanded(
            child: PageView.builder(
              itemCount: widget.tutorial.steps.length,
              onPageChanged: (i) => setState(() => _currentStep = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: widget.tutorial.color.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: widget.tutorial.color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.tutorial.steps[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.4),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Swipe to continue →',
                        style: TextStyle(fontSize: 12, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Step dots
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.tutorial.steps.length, (i) {
                return Container(
                  width: i == _currentStep ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _currentStep ? widget.tutorial.color : AppColors.outlineVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
