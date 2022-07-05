import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// https://www.youtube.com/watch?v=DhyOyqz7saM&list=PLdtFzIhH38aKQfgjcui_WSdsksoVzHoc1
// hasel em 40:00
class TetrisGame extends StatefulWidget {
  const TetrisGame({Key? key}) : super(key: key);

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  // lets make BrickShape for next object show on top

  GlobalKey<_TetrisWidgetState> keyGlobal = GlobalKey();
  ValueNotifier<List<BrickObjectPos>> brickObjectPosValue = ValueNotifier<List<BrickObjectPos>>(List<BrickObjectPos>.from([]));

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const double sizePerSquare = 40;
    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Center(child: LayoutBuilder(builder: (context, constraints) {
            // make 2 column.. one for action top, second for tetris build
            return Column(
              children: [
                Container(
                  // split top 2 row
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        // height: constraints.maxHeight,
                        width: constraints.biggest.width / 2,
                        // color: Colors.red,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // for score & line succes
                            //dummy
                            Padding(padding: EdgeInsets.all(8.0), child: Text("Score : ${null ?? 0}")),
                            Padding(padding: EdgeInsets.all(8.0), child: Text("Score : ${null ?? 0}")),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    keyGlobal.currentState!.resetGame();
                                  },
                                  child: Text("Reset"),
                                  style: ButtonStyle(backgroundColor: MaterialStateColor.resolveWith((states) => Colors.red[900]!)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    keyGlobal.currentState!.pauseGame();
                                  },
                                  child: Text("Pause"),
                                  style: ButtonStyle(backgroundColor: MaterialStateColor.resolveWith((states) => Colors.red[900]!)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: constraints.biggest.width / 2,
                        color: Colors.yellow,
                        child: Column(
                          children: [
                            Text("Next :"),
                            // contain box show next tetris,
                            // lets make default class 1st
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                              child: ValueListenableBuilder(
                                valueListenable: brickObjectPosValue,
                                builder: (context, List<BrickObjectPos> value, child) {
                                  BrickShapeEnum tempShapeEnum = value.length > 0 ? value.last.shapeEnum : BrickShapeEnum.Line;
                                  int rotation = value.length > 0 ? value.last.rotation : 0;

                                  // yeayyy

                                  return BrickShape(BrickShapeStatic.getListBrickOnEnum(
                                      // check if got value take last array.. for our next brick down..
                                      tempShapeEnum,
                                      direction: rotation));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                    child: Container(
                  width: double.maxFinite,
                  color: Colors.green,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return TetrisWidget(
                      // sent size
                      constraints.biggest,
                      key: keyGlobal,
                      // size pre box brick
                      sizePerSquare: sizePerSquare,
                      // make callback for next brick show after generate on widget
                      setNextBrick: (List<BrickObjectPos> brickObjectPos) {
                        brickObjectPosValue.value = brickObjectPos;
                        brickObjectPosValue.notifyListeners();
                      },
                    );
                  }),
                ))
              ],
            );
          })),
        ),
      ),
    );
  }
}

class TetrisWidget extends StatefulWidget {
  Function(List<BrickObjectPos> brickObjectPos)? setNextBrick;
  final Size size;
  double? sizePerSquare = 40;

  TetrisWidget(this.size, {Key? key, this.setNextBrick, this.sizePerSquare}) : super(key: key);

  @override
  State<TetrisWidget> createState() => _TetrisWidgetState();
}

class _TetrisWidgetState extends State<TetrisWidget> with SingleTickerProviderStateMixin {
  // set animation & controller animation 1st
  late Animation<double> animation;
  late AnimationController animationController;
  late Size sizeBox;

  // our index point array for base or walls
  late List<int> levelBases;

  // all brick generated will save here
  ValueNotifier<List<BrickObjectPos>> brickObjectPosValue = ValueNotifier<List<BrickObjectPos>>([]);

  // for point already done
  ValueNotifier<List<BrickObjectPosDone>> donePointsValue = ValueNotifier<List<BrickObjectPosDone>>([]);

  // declare all parameter
  ValueNotifier<int> animationPosTickValue = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    // calculate size box base size box Tetris
    calculateSizeBox();
    // generate random in animation loop

    animationController = AnimationController(vsync: this, duration: Duration(microseconds: 1000));
    animation = Tween<double>(begin: 0, end: 1).animate(animationController)..addListener(animationLoop);
    animationController.forward();
  }

  void calculateSizeBox() {
    // sizeBox to calculate overall size which need for our tetris take place
    sizeBox = Size(
      (widget.size.width ~/ widget.sizePerSquare!) * widget.sizePerSquare!,
      (widget.size.height ~/ widget.sizePerSquare!) * widget.sizePerSquare!,
    );

    // calculate bases level in game
    // this one calculate bottom level
    levelBases = List.generate(sizeBox.width ~/ widget.sizePerSquare!, (index) {
      return ((sizeBox.height ~/ widget.sizePerSquare!) - 1) * (sizeBox.width ~/ widget.sizePerSquare!) + index;
    });

    // calculate left base wall
    levelBases.addAll(List.generate(sizeBox.height ~/ widget.sizePerSquare!, (index) {
      return index * (sizeBox.width ~/ widget.sizePerSquare!);
    }));

    // calculate right base wall
    levelBases.addAll(List.generate(sizeBox.height ~/ widget.sizePerSquare!, (index) {
      return (index * (sizeBox.width ~/ widget.sizePerSquare!)) + (sizeBox.width ~/ widget.sizePerSquare! - 1);
    }));
  }

  pauseGame() async {
    animationController.stop();
    await showDialog(
        context: context,
        builder: (context) => SimpleDialog(
              children: [
                Text("Pause Game"),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      animationController.forward();
                    },
                    child: Text("Pause")),
              ],
            ));
  }

  resetGame() async {
    animationController.stop();
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SimpleDialog(
              children: [
                Text("Resume Game"),
                ElevatedButton(
                    onPressed: () {
                      donePointsValue.value = [];
                      donePointsValue.notifyListeners();

                      brickObjectPosValue.value = [];
                      brickObjectPosValue.notifyListeners();

                      Navigator.of(context).pop();

                      calculateSizeBox();
                      randomBrick(start: true);
                      animationController.reset();
                      animationController.stop();
                      animationController.forward();
                    },
                    child: Text("Start / Reset")),
              ],
            ));
  }

  void animationLoop() {
    // check brick length more that 1 for ready curent & future brick
    if (animation.isCompleted && brickObjectPosValue.value.length > 1) {
      print("nice run hahhaa");

      animationController.reset();
      animationController.forward();
    }
    // we use on rest btn
    // randomBrick(start: true);
  }

  void randomBrick({start: false}) {
    // start true means to generate 2 random brick, if false we just generate one on time
    brickObjectPosValue.value.add(getNewBrickPos());
    widget.setNextBrick!.call(brickObjectPosValue.value);
    brickObjectPosValue.notifyListeners();
  }

  BrickObjectPos getNewBrickPos() {
    return BrickObjectPos(
        size: Size.square(widget.sizePerSquare!),
        sizeLayout: sizeBox,
        color: Colors.primaries[Random().nextInt(Colors.primaries.length)].shade800,
        rotation: Random().nextInt(4),
        offset: Offset(widget.sizePerSquare! * 4, -widget.sizePerSquare! * 3),
        shapeEnum: BrickShapeEnum.values[Random().nextInt(BrickShapeEnum.values.length)]);
  }

  @override
  Widget build(BuildContext context) {
    double margin = 0;
    Border border = Border.all(width: 1, color: Colors.black);

    // let show our generate bricks
    return Container(
      alignment: Alignment.center,
      color: Colors.brown,
      child: Container(
        child: ValueListenableBuilder(
          valueListenable: donePointsValue,
          builder: (context, List<BrickObjectPosDone> donePoints, child) {
            return ValueListenableBuilder(
                valueListenable: brickObjectPosValue,
                builder: (context, List<BrickObjectPos> brickObjectPoses, child) {
                  return Stack(
                    children: [
                      // 1st generate box show our grid
                      ...List.generate(sizeBox.width ~/ widget.sizePerSquare! * sizeBox.height ~/ widget.sizePerSquare!, (index) {
                        return Positioned(
                          left: index % (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!,
                          top: index ~/ (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.red, border: Border.all(width: 1)),
                            width: widget.sizePerSquare!,
                            height: widget.sizePerSquare!,
                          ),
                        );
                      }),
                    ],
                  );
                });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // dispose run smoothly
    animation.removeListener(animationLoop);
    animationController.dispose();
    super.dispose();
  }
}

// declare enum use for tetris brick shape
enum BrickShapeEnum { Square, LShape, RLShape, ZigZag, RZigZag, TShape, Line }

//class declare
class BrickShapeStatic {
  static List<List<List<double>>> rotateLShape = [
    [
      [0, 0, 1],
      [1, 1, 1],
      [0, 0, 0],
    ],
    [
      [0, 1, 0],
      [0, 1, 0],
      [0, 1, 1],
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [1, 0, 0],
    ],
    [
      [1, 1, 0],
      [0, 1, 0],
      [0, 1, 0],
    ],
  ];

  static List<List<List<double>>> rotateRLShape = [
    [
      [1, 0, 0],
      [1, 1, 1],
      [0, 0, 0],
    ],
    [
      [0, 1, 1],
      [0, 1, 0],
      [0, 1, 0],
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [0, 0, 1],
    ],
    [
      [0, 1, 0],
      [0, 1, 0],
      [1, 1, 0],
    ],
  ];
  static List<List<List<double>>> rotateZigZag = [
    [
      [0, 0, 0],
      [1, 1, 0],
      [0, 1, 1],
    ],
    [
      [0, 1, 0],
      [1, 1, 0],
      [1, 0, 0],
    ],
    [
      [0, 0, 0],
      [1, 1, 0],
      [0, 1, 1],
    ],
    [
      [0, 1, 0],
      [1, 1, 0],
      [1, 0, 0],
    ],
  ];
  static List<List<List<double>>> rotateRZigZag = [
    [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 0],
    ],
    [
      [1, 0, 0],
      [1, 1, 0],
      [0, 1, 0],
    ],
    [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 0],
    ],
    [
      [1, 0, 0],
      [1, 1, 0],
      [0, 1, 0],
    ],
  ];
  static List<List<List<double>>> rotateTShape = [
    [
      [0, 1, 0],
      [1, 1, 1],
      [0, 0, 0],
    ],
    [
      [0, 1, 0],
      [0, 1, 1],
      [0, 1, 0],
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [0, 1, 0],
    ],
    [
      [0, 1, 0],
      [1, 1, 0],
      [0, 1, 0],
    ],
  ];
  static List<List<List<double>>> rotateLine = [
    [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ],
    [
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0],
    ],
    [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ],
    [
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0],
    ],
  ];

// declare static class method to get correct rotation

  static List<List<double>> getListBrickOnEnum(BrickShapeEnum shapeEnum, {int direction = 0}) {
    List<List<double>> shapeList;

    if (shapeEnum == BrickShapeEnum.Square) {
      shapeList = [
        [1, 1],
        [1, 1],
      ];
    } else if (shapeEnum == BrickShapeEnum.LShape) {
      shapeList = rotateLShape[direction];
    } else if (shapeEnum == BrickShapeEnum.RLShape) {
      shapeList = rotateRLShape[direction];
    } else if (shapeEnum == BrickShapeEnum.ZigZag) {
      shapeList = rotateZigZag[direction];
    } else if (shapeEnum == BrickShapeEnum.RZigZag) {
      shapeList = rotateRZigZag[direction];
    } else if (shapeEnum == BrickShapeEnum.TShape) {
      shapeList = rotateTShape[direction];
    } else if (shapeEnum == BrickShapeEnum.Line) {
      shapeList = rotateLine[direction];
    } else {
      shapeList = [];
    }
    return shapeList;
  }
}

// declare BrickObject
class BrickObject {
  bool enable;

  BrickObject({this.enable = false});
}

// declare class Brick on done
class BrickObjectPosDone {
  Color? color;
  int index;

  BrickObjectPosDone(this.index, {this.color});
}

// lastly class.. BrickObjectPos
class BrickObjectPos {
  Offset offset;
  BrickShapeEnum shapeEnum;
  int rotation;
  bool isDone;
  Size? sizeLayout;
  Size? size;
  Color color;
  List<int> pointArray = [];

  BrickObjectPos({
    this.size,
    this.sizeLayout,
    this.isDone = false,
    this.offset = Offset.zero,
    this.shapeEnum = BrickShapeEnum.Line,
    this.rotation = 0,
    this.color = Colors.amber,
  }) {
    calculateHit();
  }

  setShape(BrickShapeEnum shapeEnum) {
    this.shapeEnum = shapeEnum;
    calculateHit();
  }

  calculateRotation(int flag) {
    rotation += flag;
    calculateHit();
  }

  calculateHit({Offset? predict}) {
    List<int> lists = BrickShapeStatic.getListBrickOnEnum(shapeEnum, direction: rotation).expand((element) => element).map((e) => e.toInt()).toList();
    List<int> tempPont = lists.asMap().entries.map((e) => calculateOffset(e, lists.length, predict ?? offset)).toList();
    if (predict != null) {
      return tempPont;
    } else {
      pointArray = tempPont;
    }
  }

  int calculateOffset(MapEntry<int, int> entry, int length, Offset offsetTemp) {
    int value = entry.value;
    if (size != null) {
      if (value == 0) {
        value = -99999;
      } else {
        double left = offsetTemp.dx / size!.width + entry.key % sqrt(length);
        double top = offsetTemp.dy / size!.height + entry.key % sqrt(length);
        int index = left.toInt() + top * sizeLayout!.width ~/ size!.width;
        value = index.toInt();
      }
    }
    return value;
  }
}

// yeay done

// make state Widget
class BrickShape extends StatefulWidget {
  List<List<double>> list;
  List? points;
  double sizePerSquare;
  Color? color;

  BrickShape(this.list, {Key? key, this.color, this.points, this.sizePerSquare = 20}) : super(key: key);

  @override
  State<BrickShape> createState() => _BrickShapeState();
}

class _BrickShapeState extends State<BrickShape> {
  @override
  Widget build(BuildContext context) {
    //we make our shape here
    //calculate column number required
    int totalPointsList = widget.list.expand((element) => element).length;
    int columnNum = (totalPointsList ~/ widget.list.length);
    return Container(
      // height: 20,
      // width: 20,
      // color: Colors.black,
      width: widget.sizePerSquare * columnNum,
      child: GridView.builder(
          shrinkWrap: true,
          itemCount: totalPointsList,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columnNum, childAspectRatio: 1),
          itemBuilder: (context, index) {
            return Offstage(
              offstage: widget.list.expand((element) => element).toList()[index] == 0,
              child: boxBrick(widget.color ?? Colors.cyan, text: widget.points?[index] ?? ""),
            );
          }),
    );
  }
}

Widget boxBrick(Color color, {text = ""}) {
  return Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
    ),
  );
}
