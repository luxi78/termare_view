import 'dart:math';
import 'package:termare_view/src/foundation/character.dart';
import 'package:termare_view/src/termare_controller.dart';
import 'package:termare_view/src/utils/signale/signale.dart';

// 这个类作为终端模拟器组件较为核心的部分
// 主要在于封装了二维数组，考虑到之后的reflow功能
// 可能需要切换成以为数组
class Buffer {
  Buffer(this.controller) {
    viewRows = controller.row;
  }

  final TermareController controller;
  // TODO 可空类型有问题
  List<List<Character?>?> cache = [];
  int _position = 0;
  int get position => _position;
  int? viewRows;
  // 这是默认的limit，在 	CSI Ps ; Ps r 这个序列后，可滑动的视口会变化
  int get limit => _position + viewRows!;
  int maxLine = 1000;
  bool isCsiR = false;
  int get length => cache.length;

  // 在 csi r 序列到来时，
  Map<int, List<Character?>> fixedLine = {};
  void clear() {
    cache.clear();
  }

  @override
  bool operator ==(dynamic other) {
    // 判断是否是非
    if (other is! Buffer) {
      return false;
    }
    if (other is Buffer) {
      return other.hashCode == hashCode;
    }
    return false;
  }

  @override
  int get hashCode => cache.hashCode;
  void setViewPoint(int rows) {
    // print('setViewPoint -> $rows');
    viewRows = rows;
    if (rows != controller.row) {
      Log.i('开始缓存');
      for (int i = rows; i < controller.row; i++) {
        // print('缓存第${i + 1}行');
        fixedLine[i] = [];
        fixedLine[i]!.length = controller.row;
        // String line = '';
        // for (int column = 0; column < controller.column; column++) {
        //   final Character character = getCharacter(i, column);
        //   if (character == null) {
        //     line += ' ';
        //     continue;
        //   }
        //   line += character.content;
        // }
        // print('这行->$line');
      }
      // for (int i = rows; i < controller.row; i++) {
      //   cache.removeAt(rows);
      // }
    } else {
      fixedLine.clear();
    }
  }

  /// 可能存在cache很长的情况，但是后面的很多行都没有内容
  int absoluteLength() {
    final int endRow = cache.length - 1;
    // print('cache.length -> ${cache.length}');
    for (int row = endRow; row > 0; row--) {
      final List<Character?>? line = cache[row];
      // 这个 line == null 不能删！！！，用非空模式运行这个库会出现问题的
      if (line == null || line.isEmpty) {
        continue;
      }
      // print(line);
      for (final Character? character in line) {
        final bool? isNotEmpty = character?.content.isNotEmpty;
        if (isNotEmpty != null && isNotEmpty) {
          // print(
          //     'row + 1:${row + 1} currentPointer.y + 1 :${currentPointer.y + 1}');
          return max(row + 1, controller.currentPointer.y + 1);
        }
      }
    }
    return controller.currentPointer.y;
  }

  int getRowLength(int row) {
    final List<Character?> line = getCharacterLines(row);
    final int endColumn = line.length - 1;
    for (int column = endColumn; column > 0; column--) {
      final Character? character = line[column];
      final bool? isNotEmpty = character?.content.isNotEmpty;
      if (isNotEmpty != null && isNotEmpty) {
        // print('$character ${column + 1}');
        return column + 1;
      }
    }
    return 0;
  }

  void write(int row, int column, Character? entity) {
    if (row >= maxLine) {
      // TODO 有问题，不用怀疑,.
      // print('ro - max ${row - maxLine}');
      cache.removeAt(0);
      cache.add([]);
      row -= 1;
      controller.moveToRelativeRow(-1);
      _position -= 1;
    }
    // print(
    //     'write row:$row length:$length column:$column $entity position:$position');
    if (row > length - 1) {
      // 防止在row上越界
      cache.length = row + 1;
      cache[row] = [];
    }
    if (cache[row] == null) {
      // 有可能存在[null,null]，这个index能取到值，但是为null
      cache[row] = [];
    }
    if (column > cache[row]!.length - 1) {
      // 防止在 column 上越界
      // Log.w(' 防止在 column 上越界');
      cache[row]!.length = column + 1;
    }
    if (fixedLine.containsKey(row - position)) {
      fixedLine[row - position]![column] = entity;
      isCsiR = false;
      for (int i = row - position; i < controller.row; i++) {
        String line = '';
        for (int column = 0; column < controller.column; column++) {
          final Character? character = getCharacter(i, column);
          if (character == null) {
            line += ' ';
            continue;
          }
          line += character.content;
        }
        Log.i('写入固定行${row - position} 行内内容->$line');
      }
    } else {
      cache[row]![column] = entity;
    }
    // printBuffer();
  }

  /// 这是一个能够打印出当前buffer content的方法
  void printBuffer() {
    for (int row = 0; row < controller.row; row++) {
      // print(lines);
      // print(getCharacterLines(row));
      String line = '$row:';
      for (int column = 0; column < controller.column; column++) {
        final Character? character = getCharacter(row, column);
        if (character == null) {
          line += ' ';
          continue;
        }
        line += character.content;
      }
      Log.i('->$line<-');
    }
  }

  Character? getCharacter(
    int row,
    int column,
  ) {
    // print('getCharacter $row $column $length');
    if (row + _position > length - 1) {
      cache.length = row + _position + 1;
      cache[row + _position] = [];
    }
    final List<Character?> lines = getCharacterLines(row);
    if (column > lines.length - 1) {
      lines.length = column + _position + 1;
    }
    return lines[column];
  }

  bool isEmptyLine(int row) {
    // 判断绝对行是否为空
    if (row > cache.length - 1) {
      return true;
    }
    final List<Character?> line = cache[row]!;
    if (line == null || line.isEmpty) {
      return true;
    }
    line.length = controller.column;
    for (int i = 0; i < controller.column; i++) {
      if (line[i] != null) {
        return false;
      }
    }
    return true;
  }

  bool isFullLine(int row) {
    // 判断绝对行是否为满
    if (row > cache.length - 1) {
      return false;
    }
    final List<Character?> line = cache[row]!;
    // 有问题，非空模式运行的时候，可能还是会拿到空
    if (line == null || line.isEmpty) {
      return false;
    }
    if (line.length < controller.column) {
      return false;
    }
    for (int i = 0; i < controller.column; i++) {
      if (line[i] == null) {
        return false;
      }
    }
    return true;
  }

  List<Character?> getCharacterLines(
    int row,
  ) {
    if (fixedLine.isNotEmpty && fixedLine.containsKey(row)) {
      return fixedLine[row]!;
    }
    if (row + _position > length - 1) {
      cache.length = row + _position + 1;
      cache[row + _position] = [];
    }
    if (cache[row + _position] == null) {
      cache[row + _position] = [];
    }
    return cache[row + _position]!;
  }

  /// 通过改变position从而实现终端视图滚动
  void scroll(int line) {
    // print(absoluteLength());
    _position += line;
    // _position = max(0, _position);
    if (absoluteLength() > viewRows!) {
      if (viewRows != controller.row) {
        // print('!!!!!');
        // final tmp = cache[limit - 2];
        // print('tmp[0].content ->${tmp[0].content}${tmp[1].content}');
        // // final tmp2 = cache[limit - 1];
        // // print('tmp[0].content ->${tmp2[0].content}${tmp2[1].content}');
        // cache[limit - 2] = cache[limit - 1];
        // cache[limit - 1] = tmp;
      }
      _position = min(absoluteLength() - viewRows!, _position);
      _position = max(0, _position);
    } else {
      // 真实高度比终端可是高度还小
      // 也就是说当前终端显示的内容还不足一页
      _position = 0;
    }
    // print('_position -> $_position');
  }
}
