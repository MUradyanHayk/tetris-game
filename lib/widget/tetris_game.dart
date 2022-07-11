import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// https://www.youtube.com/watch?v=DhyOyqz7saM&list=PLdtFzIhH38aKQfgjcui_WSdsksoVzHoc1
// hasel em 1:06:30
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
    const double sizePerSquare = 20;
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
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
                        alignment: Alignment.center,
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
                  alignment: Alignment.center,
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
                )),
                Container(
                  color: Colors.red,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => keyGlobal.currentState!.transformBrick(move: Offset(-sizePerSquare, 0)),
                        child: Text("Left"),
                      ),
                      ElevatedButton(
                        onPressed: () => keyGlobal.currentState!.transformBrick(move: Offset(sizePerSquare, 0)),
                        child: Text("Right"),
                      ),
                      ElevatedButton(
                        onPressed: () => keyGlobal.currentState!.transformBrick(move: Offset(0, sizePerSquare)),
                        child: Text("Bottom"),
                      ),
                      ElevatedButton(
                        onPressed: () => keyGlobal.currentState!.transformBrick(rotate: true),
                        child: Text("Rotate"),
                      ),
                    ],
                  ),
                ),
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
  double? sizePerSquare = 20;

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

  void animationLoop() async {
    // check brick length more that 1 for ready current & future brick
    if (animation.isCompleted && brickObjectPosValue.value.length > 1) {
      print("nice run hahhaa");

      // get current move
      BrickObjectPos currentObj = brickObjectPosValue.value[brickObjectPosValue.value.length - 2];

      // calculate offset target on animate
      Offset target = currentObj.offset.translate(0, widget.sizePerSquare!);

      // check target move exceed wall or base,, if exceed then do nothing.. make done

      if (checkTargetMove(target, currentObj)) {
        currentObj.offset = target;
        currentObj.calculateHit();
        brickObjectPosValue.notifyListeners();
      } else {
        // currentObj.isDone = true;
        // add to done for current object hit
        currentObj.pointArray.where((element) => element != -99999).toList().forEach((element) {
          donePointsValue.value.add(BrickObjectPosDone(element, color: currentObj.color));
        });

        donePointsValue.notifyListeners();

        // remove second last array
        // show on our layput 1st
        brickObjectPosValue.value.removeAt(brickObjectPosValue.value.length - 2);

        // check complete line

        await checkCompleteLine();

        // check game over
        bool status = await checkGameOver();

        if (!status) {
          // generate new brick
          // yeayyy ops.. we proceed with movement 1st..make button
          randomBrick();
        } else {
          print("Game Over");
        }
      }

      animationController.reset();
      animationController.forward();
    }
    // we use on rest btn
    // randomBrick(start: true);
  }

  Future<bool> checkGameOver() async {
    return donePointsValue.value.where((element) => element.index < 0 && element.index != -99999).length > 0;
  }

  checkCompleteLine() async {
    // later we put full code
    // let finish
    List<int> leftIndex = List.generate(sizeBox.height ~/ widget.sizePerSquare!, (index) {
      return index * ((sizeBox.width ~/ widget.sizePerSquare!));
    });

    int totalCol = (sizeBox.width ~/ widget.sizePerSquare!) - 2;
    List<int> lineToDestroys = leftIndex
        .where((element) {
          return donePointsValue.value.where((point) => point.index == element + 1).length > 0;
        })
        .where((donePoint) {
          List<int> rows = List.generate(totalCol, (index) => donePoint + 1 + index).toList();
          return rows.where((row) {
                return donePointsValue.value.where((element) => element.index == row).length > 0;
              }).length ==
              rows.length;
        })
        .map((e) {
          return List.generate(totalCol, (index) => e + 1 + index).toList();
        })
        .expand((element) => element)
        .toList();

    List<BrickObjectPosDone> tempDonnePoints = donePointsValue.value;

    if (lineToDestroys.length > 0) {
      lineToDestroys.sort((a, b) => a.compareTo(b));
      tempDonnePoints.sort((a, b) => a.index.compareTo(b.index));

      int firstIndex = tempDonnePoints.indexWhere((element) => element.index == lineToDestroys.first);

      if (firstIndex >= 0) {
              tempDonnePoints.removeWhere((element) {
               return lineToDestroys.where((line) => line == element.index).length > 0;
              });

              donePointsValue.value = tempDonnePoints.map((element) {
                if (element.index < lineToDestroys.first) {
                  int totalRowDelete = lineToDestroys.length ~/ totalCol;
                  element.index = element.index + ((totalCol+2)* totalRowDelete);
                }
                return element;
              }).toList();

              donePointsValue.notifyListeners();

      }
    }
  }

  bool checkTargetMove(Offset targetPos, BrickObjectPos object) {
    List<int> pointsPredict = object.calculateHit(predict: targetPos);

    List<int> hitsIndex = [];

    // add all wall for hits index
    hitsIndex.addAll(levelBases);

    // add all point done for hits index
    hitsIndex.addAll(donePointsValue.value.map((e) => e.index));

    // get number hit on points hit
    int numberHitBase = pointsPredict.map((e) => hitsIndex.indexWhere((element) => element == e) > -1).where((element) => element).length;

    return numberHitBase == 0;
  }

  void randomBrick({start: false}) {
    // start true means to generate 2 random brick, if false we just generate one on time
    brickObjectPosValue.value.add(getNewBrickPos());
    if (start) {
      brickObjectPosValue.value.add(getNewBrickPos());
    }
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
      width: sizeBox.width,
      height: sizeBox.height,
      alignment: Alignment.center,
      color: Colors.brown,
      child: Container(
        color: Colors.white,
        width: sizeBox.width,
        height: sizeBox.height,
        alignment: Alignment.center,
        child: ValueListenableBuilder(
          valueListenable: donePointsValue,
          builder: (context, List<BrickObjectPosDone> donePoints, child) {
            return ValueListenableBuilder(
                valueListenable: brickObjectPosValue,
                builder: (context, List<BrickObjectPos> brickObjectPoses, child) {
                  return Stack(
                    children: [
                      // 1st generate box show our grid
                      // last.. we clear line full
                      ...List.generate(sizeBox.width ~/ widget.sizePerSquare! * sizeBox.height ~/ widget.sizePerSquare!, (index) {
                        return Positioned(
                          left: index % (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!,
                          top: index ~/ (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!,
                          child: Container(
                            decoration: BoxDecoration(
                              // let make wall defined by our lists before
                              color: checkIndexHitBase(index) ? Colors.black87 : Colors.transparent,
                              border: Border.all(width: 1),
                            ),
                            width: widget.sizePerSquare!,
                            height: widget.sizePerSquare!,
                            child: Text(
                              "${checkIndexHitBase(index) ? index : ""}",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }).toList(),
                      // lets show bricks
                      // move our brick for demo
                      if (brickObjectPoses.length > 1)
                        ...brickObjectPoses
                            .where((element) => !element.isDone)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (e) => Positioned(
                                left: e.value.offset.dx,
                                top: e.value.offset.dy,
                                child: BrickShape(
                                  BrickShapeStatic.getListBrickOnEnum(
                                    e.value.shapeEnum,
                                    direction: e.value.rotation,
                                  ),
                                  sizePerSquare: widget.sizePerSquare!,
                                  points: e.value.pointArray,
                                  color: e.value.color,
                                ),
                              ),
                            )
                            .toList(),
                      if (donePoints.length > 0)
                        ...donePoints.map(
                          (e) => Positioned(
                            left: e.index % (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!,
                            top: (e.index ~/ (sizeBox.width / widget.sizePerSquare!) * widget.sizePerSquare!).toDouble(),
                            child: boxBrick(e.color!, text: e.index),
                            width: widget.sizePerSquare!,
                            height: widget.sizePerSquare!,
                          ),
                        )
                    ],
                  );
                });
          },
        ),
      ),
    );
  }

  checkIndexHitBase(int index) {
    return levelBases.indexWhere((element) => element == index) != -1;
  }

  @override
  void dispose() {
    // dispose run smoothly
    animation.removeListener(animationLoop);
    animationController.dispose();
    super.dispose();
  }

  transformBrick({Offset? move, bool? rotate}) {
    if (move != null || rotate != null) {
      // get current move
      BrickObjectPos currentObj = brickObjectPosValue.value[brickObjectPosValue.value.length - 2];

      // calculate offset target on animate
      late Offset target;
      if (move != null) {
        target = currentObj.offset.translate(move.dx, move.dy);

        if (checkTargetMove(target, currentObj)) {
          currentObj.offset = target;
          currentObj.calculateHit();
          brickObjectPosValue.notifyListeners();
        }
      } else {
        // currentObj.calculateRotation(1);
        // BrickObjectPos temCurrent = BrickObjectPos.clone(currentObj);
        currentObj.calculateRotation(1);
        if (checkTargetMove(currentObj.offset, currentObj)) {
          currentObj.calculateHit();
          brickObjectPosValue.notifyListeners();
        } else {
          currentObj.calculateRotation(-1);
        }
      }

      // check target move exceed wall or base,, if exceed then do nothing.. make done

    }
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
      shapeList = rotateLShape[direction % 4];
    } else if (shapeEnum == BrickShapeEnum.RLShape) {
      shapeList = rotateRLShape[direction % 4];
    } else if (shapeEnum == BrickShapeEnum.ZigZag) {
      shapeList = rotateZigZag[direction % 4];
    } else if (shapeEnum == BrickShapeEnum.RZigZag) {
      shapeList = rotateRZigZag[direction % 4];
    } else if (shapeEnum == BrickShapeEnum.TShape) {
      shapeList = rotateTShape[direction % 4];
    } else if (shapeEnum == BrickShapeEnum.Line) {
      shapeList = rotateLine[direction % 4];
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

  static clone(BrickObjectPos object) {
    return BrickObjectPos(
      offset: object.offset,
      shapeEnum: object.shapeEnum,
      rotation: object.rotation,
      isDone: object.isDone,
      sizeLayout: object.sizeLayout,
      size: object.size,
      color: object.color,
    );
  }

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
        double top = offsetTemp.dy / size!.height + entry.key ~/ sqrt(length);
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
