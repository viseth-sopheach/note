import 'package:flutter/widgets.dart';

import 'paper_painter.dart';

/// Extra drawable area around the paper, in document units.
const double kBleedX = 160;
const double kBleedY = 28;

/// Paper corner inside a page cell.
const Offset kPaperOrigin = Offset(kBleedX, kBleedY);

/// Paper plus the drawable margin around it.
final Size kCellSize = Size(
  kPageSize.width + kBleedX * 2,
  kPageSize.height + kBleedY * 2,
);