import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

typedef TitleBuilder = String Function({
  required String colorName,
  required String gridSize,
});

typedef DescriptionBuilder = String Function({
  required String colorName,
  required String gridSize,
});

class ChallengeTypeConfig {
  final String id;
  final String displayName;
  final IconData icon;
  final TitleBuilder titleBuilder;
  final DescriptionBuilder descriptionBuilder;
  final String blurb;
  final bool? selectable;

  const ChallengeTypeConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.titleBuilder,
    required this.descriptionBuilder, 
    required this.blurb,
    this.selectable = true, 
  });
}

final Map<String, ChallengeTypeConfig> challengeTypes = {
  "SingleColorGrid": ChallengeTypeConfig(
    id: "SingleColorGrid",
    displayName: "Single-Color Hunt",
    icon: Icons.palette,

    titleBuilder: ({required colorName, required gridSize}) {
      return "$colorName Color Hunt";
    },

    descriptionBuilder: ({required colorName, required gridSize}) {
      final count = gridSize.replaceAll('x', '×');
      return "Find and capture $count items matching the color ${colorName.toLowerCase()}.";
    }, 
    blurb: 'Go on a color-based scavenger hunt and capture items that fit the theme.',
  ),
  "Coming Soon": ChallengeTypeConfig(
    id: "coming-soon",
    displayName: "Coming Soon",
    icon: Icons.lock,

    titleBuilder: ({required colorName, required gridSize}) {
      return "Coming Soon";
    },

    descriptionBuilder: ({required colorName, required gridSize}) {
      return "More challenge modes";
    },
    selectable: false, 
    blurb: 'More challenge modes soon'
  ),
  // Future possibilities
  // "Multi-Color Hunt": ChallengeTypeConfig(
  //   id: "Multi-Color Hunt",
  //   displayName: "Multi-Color Hunt",
  //   icon: Icons.gradient,

  //   titleBuilder: ({required colorName, required gridSize}) {
  //     return "Multi-Color Hunt";
  //   },

  //   descriptionBuilder: ({required colorName, required gridSize}) {
  //     return "Capture a grid of items across multiple colors.";
  //   },
  // ),

  // "Timed Hunt": ChallengeTypeConfig(
  //   id: "Timed Hunt",
  //   displayName: "Timed Hunt",
  //   icon: Icons.timer,

  //   titleBuilder: ({required colorName, required gridSize}) {
  //     return "Timed Color Rush";
  //   },

  //   descriptionBuilder: ({required colorName, required gridSize}) {
  //     return "You have limited time to capture as many $colorName items as possible.";
  //   },
  // ),
};

class CreateChallenge extends StatefulWidget {
  const CreateChallenge({super.key});

  @override
  State<CreateChallenge> createState() => _CreateChallengeState();
}

class _CreateChallengeState extends State<CreateChallenge> {
  final PageController _pageController = PageController(viewportFraction: 0.90);

  String selectedType = "SingleColorGrid";
  String gridSize = "3x3";

  Color selectedColor = Colors.red;
  String colorName = "Red";

  final List<String> gridOptions = ["2x2","3x3", "4x4", "5x5"];

  final List<Map<String, dynamic>> swatches = [
    {"name": "Red", "color": Colors.red},
    {"name": "Crimson", "color": const Color(0xFFDC143C)},
    {"name": "Orange", "color": Colors.orange},
    {"name": "Amber", "color": Colors.amber},
    {"name": "Yellow", "color": Colors.yellow},
    {"name": "Lime", "color": Colors.lime},
    {"name": "Green", "color": Colors.green},
    {"name": "Mint", "color": const Color(0xFF98FF98)},
    {"name": "Teal", "color": Colors.teal},
    {"name": "Cyan", "color": Colors.cyan},
    {"name": "Sky", "color": const Color(0xFF87CEEB)},
    {"name": "Blue", "color": Colors.blue},
    {"name": "Indigo", "color": Colors.indigo},
    {"name": "Purple", "color": Colors.purple},
    {"name": "Magenta", "color": const Color(0xFFFF00FF)},
    {"name": "Pink", "color": Colors.pink},
    {"name": "Rose", "color": const Color(0xFFFFC0CB)},
    {"name": "Brown", "color": Colors.brown},
    {"name": "Gray", "color": Colors.grey},
    {"name": "Black", "color": Colors.black},
  ];

  ChallengeTypeConfig get currentType => challengeTypes[selectedType]!;

  String get autoTitle => currentType.titleBuilder(
        colorName: colorName,
        gridSize: gridSize,
      );
  int get autoMaxProgress => gridSize.toLowerCase().split('x').fold(1, (oldVal, newVal){
    return oldVal * (int.tryParse(newVal) ?? 1);
  });


  String get autoDescription => currentType.descriptionBuilder(
        colorName: colorName,
        gridSize: gridSize,
      );

  String get colorHex => '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

  String smartColorName(Color color) {
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    final lightness = hsl.lightness;
    final saturation = hsl.saturation;

    if (lightness < 0.12) return "Black";
    if (lightness > 0.92) return "White";
    if (saturation < 0.18) return "Gray";

    if (hue < 15 || hue >= 345) return "Red";
    if (hue < 40) return "Orange";
    if (hue < 65) return "Yellow";
    if (hue < 150) return "Green";
    if (hue < 200) return "Teal";
    if (hue < 250) return "Blue";
    if (hue < 290) return "Purple";
    if (hue < 345) return "Pink";

    return "Custom";
  }

  Future<void> pickCustomColor() async {
    Color temp = selectedColor;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Pick Custom Color"),
          content: ColorPicker(
            color: temp,
            onColorChanged: (c) => temp = c,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedColor = temp;
                  colorName = smartColorName(temp);
                });
                Navigator.pop(context);
              },
              child: const Text("Select"),
            ),
          ],
        );
      },
    );
  }

  void submitChallenge() {
    Navigator.pop(context, {
      "type": selectedType,
      "name": autoTitle,
      "description": autoDescription,
      "gridSize": gridSize,
      "ruleSet": '$selectedType$gridSize',
      'maxProgress': autoMaxProgress,
      "target": {
        "colorName": colorName,
        "hexApprox": colorHex,
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modes = challengeTypes.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("New Challenge")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    selectedColor.withValues(alpha:0.18),
                    selectedColor.withValues(alpha:0.06),
                  ],
                ),
                border: Border.all(
                  color: selectedColor.withValues(alpha:0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: selectedColor.withValues(alpha:0.18),
                  ),
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha:0.06),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedColor,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: selectedColor.withValues(alpha:0.4),
                        ),
                      ],
                    ),
                    child: Icon(
                      currentType.icon,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          autoTitle,
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "$gridSize • $colorHex",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha:0.75),
                          ),
                        ),
                        const SizedBox(height: 8),

                      /// COMPACT DESCRIPTION
                      Text(
                        autoDescription,
                        style: TextStyle(
                          fontSize: 13.6,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Text("Challenge Type", style: Theme.of(context).textTheme.titleMedium),
                Spacer(),
                Icon(Icons.arrow_back_ios, size: 15,),
                Icon(Icons.arrow_forward_ios, size: 15),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 110,
              child: PageView.builder(
                controller: _pageController,
                itemCount: modes.length,
                onPageChanged: (index) {
                  if (index == modes.length-1) return;

                  setState(() {
                    selectedType = modes[index].id;
                  });
                },
                itemBuilder: (context, index) {
                  final mode = modes[index];
                  final bool isSelected = selectedType == mode.id;

                  return AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: isSelected ? 1.0 : 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          if (!(mode.selectable ?? true)) return;

                          setState(() {
                            selectedType = mode.id;
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: isSelected ? LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                              ]
                            ) : null,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: isSelected ? 14 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                mode.icon,
                                size: 34,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      mode.blurb,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),


            const SizedBox(height: 20),

            if (selectedType == "SingleColorGrid") ...[
              Text("Grid Size", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                children: gridOptions.map((size) {
                  final selected = gridSize == size;
                  return ChoiceChip(
                    label: Text(size),
                    selected: selected,
                    selectedColor:
                        Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => gridSize = size),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),
            ],

            Text("Pick Color", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                const double swatchSize = 34;
                const double spacing = 10;
                final countPerRow =
                    (constraints.maxWidth / (swatchSize + spacing)).floor();

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: countPerRow,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: swatches.length + 1,
                  itemBuilder: (context, index) {

                    if (index == swatches.length) {
                      return GestureDetector(
                        onTap: pickCustomColor,
                        child: Container(
                          width: swatchSize,
                          height: swatchSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      );
                    }

                    final item = swatches[index];
                    final selected = item["name"] == colorName;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColor = item["color"];
                          colorName = item["name"];
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: swatchSize,
                        height: swatchSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item["color"],
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: selected ? 8 : 3,
                              spreadRadius: selected ? 1 : 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: submitChallenge,
        child: const Icon(Icons.check),
      ),
    );
  }
}
