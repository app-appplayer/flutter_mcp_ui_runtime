// Every property promoted into the registry in spec 1.4.1, exercised as a
// *value property* — separate from the action slots, which live in
// `promoted_actions_test.dart`.
//
// The split matters because the same name means different things depending on
// where it sits: `blur` is a number on a decoration and an action on a field,
// `style` is an enum on `button` and a `TextStyle` on `textInput`, `size` is a
// preset on `numberStepper` and a measurement elsewhere. A suite that mixed
// the two kinds could pass while a slot was declared as the wrong one.
//
// Each case carries the widget's required properties plus the promoted one at
// its declared type. A promotion that names a type the implementation does not
// read — which is how `liveRegion`, `focusGroup`, `badge.smallSize` and
// `numberStepper.size` were caught — fails here.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcp_ui_core/flutter_mcp_ui_core.dart';

void main() {
  const cases = <Map<String, dynamic>>[
    <String, dynamic>{'type': 'accessibleWrapper', 'announceNavigation': true},  // accessibleWrapper.announceNavigation
    <String, dynamic>{'type': 'accessibleWrapper', 'announceOnChange': true},  // accessibleWrapper.announceOnChange
    <String, dynamic>{'type': 'accessibleWrapper', 'autoFocus': true},  // accessibleWrapper.autoFocus
    <String, dynamic>{'type': 'accessibleWrapper', 'focusGroup': 'x'},  // accessibleWrapper.focusGroup
    <String, dynamic>{'type': 'accessibleWrapper', 'focusOrder': 2},  // accessibleWrapper.focusOrder
    <String, dynamic>{'type': 'accessibleWrapper', 'liveRegion': 'polite'},  // accessibleWrapper.liveRegion
    <String, dynamic>{'type': 'accessibleWrapper', 'navigationMessage': 'x'},  // accessibleWrapper.navigationMessage
    <String, dynamic>{'type': 'accessibleWrapper', 'watchPath': 'x'},  // accessibleWrapper.watchPath
    <String, dynamic>{'type': 'alertDialog', 'clipBehavior': 'x'},  // alertDialog.clipBehavior
    <String, dynamic>{'type': 'alertDialog', 'insetPadding': 2},  // alertDialog.insetPadding
    <String, dynamic>{'type': 'alertDialog', 'scrollable': true},  // alertDialog.scrollable
    <String, dynamic>{'type': 'alertDialog', 'shadowColor': '#112233'},  // alertDialog.shadowColor
    <String, dynamic>{'type': 'alertDialog', 'shape': <String, dynamic>{}},  // alertDialog.shape
    <String, dynamic>{'type': 'alertDialog', 'surfaceTintColor': '#112233'},  // alertDialog.surfaceTintColor
    <String, dynamic>{'type': 'align', 'heightFactor': 2},  // align.heightFactor
    <String, dynamic>{'type': 'align', 'widthFactor': 2},  // align.widthFactor
    <String, dynamic>{'type': 'animatedContainer', 'clipBehavior': 'x'},  // animatedContainer.clipBehavior
    <String, dynamic>{'type': 'animatedContainer', 'constraints': <String, dynamic>{}},  // animatedContainer.constraints
    <String, dynamic>{'type': 'animatedContainer', 'foregroundDecoration': <String, dynamic>{'color': '#112233'}},  // animatedContainer.foregroundDecoration
    <String, dynamic>{'type': 'animatedContainer', 'transform': <dynamic>[]},  // animatedContainer.transform
    <String, dynamic>{'type': 'animatedContainer', 'transformAlignment': 'center'},  // animatedContainer.transformAlignment
    <String, dynamic>{'type': 'badge', 'isLabelVisible': true},  // badge.isLabelVisible
    <String, dynamic>{'type': 'badge', 'offset': <String, dynamic>{}},  // badge.offset
    <String, dynamic>{'type': 'badge', 'smallSize': true},  // badge.smallSize
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'enableFeedback': true},  // bottomNavigation.enableFeedback
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'fixedColor': '#112233'},  // bottomNavigation.fixedColor
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'iconSize': 12},  // bottomNavigation.iconSize
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'selectedFontSize': 12},  // bottomNavigation.selectedFontSize
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'selectedIconTheme': <String, dynamic>{}},  // bottomNavigation.selectedIconTheme
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'selectedItemColor': '#112233'},  // bottomNavigation.selectedItemColor
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'selectedLabelStyle': <String, dynamic>{'fontSize': 12}},  // bottomNavigation.selectedLabelStyle
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'showSelectedLabels': true},  // bottomNavigation.showSelectedLabels
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'showUnselectedLabels': true},  // bottomNavigation.showUnselectedLabels
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'unselectedFontSize': 12},  // bottomNavigation.unselectedFontSize
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'unselectedIconTheme': <String, dynamic>{}},  // bottomNavigation.unselectedIconTheme
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'unselectedItemColor': '#112233'},  // bottomNavigation.unselectedItemColor
    <String, dynamic>{'type': 'bottomNavigation', 'items': <dynamic>[], 'unselectedLabelStyle': <String, dynamic>{'fontSize': 12}},  // bottomNavigation.unselectedLabelStyle
    <String, dynamic>{'type': 'bottomSheet', 'clipBehavior': 'x'},  // bottomSheet.clipBehavior
    <String, dynamic>{'type': 'bottomSheet', 'constraints': <String, dynamic>{}},  // bottomSheet.constraints
    <String, dynamic>{'type': 'bottomSheet', 'dragHandleColor': '#112233'},  // bottomSheet.dragHandleColor
    <String, dynamic>{'type': 'bottomSheet', 'dragHandleSize': <String, dynamic>{}},  // bottomSheet.dragHandleSize
    <String, dynamic>{'type': 'bottomSheet', 'shadowColor': '#112233'},  // bottomSheet.shadowColor
    <String, dynamic>{'type': 'bottomSheet', 'showDragHandle': true},  // bottomSheet.showDragHandle
    <String, dynamic>{'type': 'box', 'constraints': <String, dynamic>{}},  // box.constraints
    <String, dynamic>{'type': 'button', 'ariaLabel': 'x'},  // button.ariaLabel
    <String, dynamic>{'type': 'button', 'borderWidth': 12},  // button.borderWidth
    <String, dynamic>{'type': 'button', 'fullWidth': true},  // button.fullWidth
    <String, dynamic>{'type': 'button', 'iconPosition': 'x'},  // button.iconPosition
    <String, dynamic>{'type': 'button', 'size': 12},  // button.size
    <String, dynamic>{'type': 'calendar', 'eventColor': '#112233'},  // calendar.eventColor
    <String, dynamic>{'type': 'calendar', 'firstDayOfWeek': 2},  // calendar.firstDayOfWeek
    <String, dynamic>{'type': 'calendar', 'height': 12},  // calendar.height
    <String, dynamic>{'type': 'calendar', 'primaryColor': '#112233'},  // calendar.primaryColor
    <String, dynamic>{'type': 'calendar', 'showHeader': true},  // calendar.showHeader
    <String, dynamic>{'type': 'calendar', 'showWeekNumbers': true},  // calendar.showWeekNumbers
    <String, dynamic>{'type': 'calendar', 'todayColor': '#112233'},  // calendar.todayColor
    <String, dynamic>{'type': 'card', 'clipBehavior': 'x'},  // card.clipBehavior
    <String, dynamic>{'type': 'card', 'semanticContainer': true},  // card.semanticContainer
    <String, dynamic>{'type': 'card', 'shadowColor': '#112233'},  // card.shadowColor
    <String, dynamic>{'type': 'card', 'surfaceTintColor': '#112233'},  // card.surfaceTintColor
    <String, dynamic>{'type': 'center', 'heightFactor': 2},  // center.heightFactor
    <String, dynamic>{'type': 'center', 'widthFactor': 2},  // center.widthFactor
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'colors': <dynamic>[]},  // chart.colors
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'labelColor': '#112233'},  // chart.labelColor
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'primaryColor': '#112233'},  // chart.primaryColor
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'showGrid': true},  // chart.showGrid
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'showLabels': true},  // chart.showLabels
    <String, dynamic>{'type': 'chart', 'chartType': 'line', 'data': <String, dynamic>{}, 'showLegend': true},  // chart.showLegend
    <String, dynamic>{'type': 'chip', 'label': 'x', 'deleteIcon': 'home'},  // chip.deleteIcon
    <String, dynamic>{'type': 'chip', 'label': 'x', 'padding': 2},  // chip.padding
    <String, dynamic>{'type': 'chip', 'label': 'x', 'shadowColor': '#112233'},  // chip.shadowColor
    <String, dynamic>{'type': 'chip', 'label': 'x', 'shape': <String, dynamic>{}},  // chip.shape
    <String, dynamic>{'type': 'chip', 'label': 'x', 'side': <String, dynamic>{}},  // chip.side
    <String, dynamic>{'type': 'clipOval', 'clipBehavior': 'x'},  // clipOval.clipBehavior
    <String, dynamic>{'type': 'clipRRect', 'clipBehavior': 'x'},  // clipRRect.clipBehavior
    <String, dynamic>{'type': 'codeEditor', 'lineNumberColor': '#112233'},  // codeEditor.lineNumberColor
    <String, dynamic>{'type': 'customDialog', 'actions': <dynamic>[]},  // customDialog.actions
    <String, dynamic>{'type': 'customDialog', 'clipBehavior': 'x'},  // customDialog.clipBehavior
    <String, dynamic>{'type': 'customDialog', 'insetPadding': 2},  // customDialog.insetPadding
    <String, dynamic>{'type': 'customDialog', 'shadowColor': '#112233'},  // customDialog.shadowColor
    <String, dynamic>{'type': 'customDialog', 'shape': <String, dynamic>{}},  // customDialog.shape
    <String, dynamic>{'type': 'customDialog', 'surfaceTintColor': '#112233'},  // customDialog.surfaceTintColor
    <String, dynamic>{'type': 'dateField', 'errorText': 'x'},  // dateField.errorText
    <String, dynamic>{'type': 'datePicker', 'initialDate': 'x'},  // datePicker.initialDate
    <String, dynamic>{'type': 'dateRangePicker', 'errorText': 'x'},  // dateRangePicker.errorText
    <String, dynamic>{'type': 'decoration', 'position': 'x'},  // decoration.position
    <String, dynamic>{'type': 'divider', 'height': 12},  // divider.height
    <String, dynamic>{'type': 'divider', 'vertical': true},  // divider.vertical
    <String, dynamic>{'type': 'draggable', 'data': 'x', 'affinity': 'x'},  // draggable.affinity
    <String, dynamic>{'type': 'draggable', 'data': 'x', 'axis': 'x'},  // draggable.axis
    <String, dynamic>{'type': 'draggable', 'data': 'x', 'dragAnchorStrategy': 'x'},  // draggable.dragAnchorStrategy
    <String, dynamic>{'type': 'drawer', 'semanticLabel': 'x'},  // drawer.semanticLabel
    <String, dynamic>{'type': 'drawer', 'shadowColor': '#112233'},  // drawer.shadowColor
    <String, dynamic>{'type': 'drawer', 'shape': <String, dynamic>{}},  // drawer.shape
    <String, dynamic>{'type': 'drawer', 'surfaceTintColor': '#112233'},  // drawer.surfaceTintColor
    <String, dynamic>{'type': 'fileExplorer', 'iconColor': '#112233'},  // fileExplorer.iconColor
    <String, dynamic>{'type': 'fittedBox', 'clipBehavior': 'x'},  // fittedBox.clipBehavior
    <String, dynamic>{'type': 'floatingActionButton', 'autofocus': true},  // floatingActionButton.autofocus
    <String, dynamic>{'type': 'floatingActionButton', 'clipBehavior': 'x'},  // floatingActionButton.clipBehavior
    <String, dynamic>{'type': 'floatingActionButton', 'disabledElevation': 12},  // floatingActionButton.disabledElevation
    <String, dynamic>{'type': 'floatingActionButton', 'focusColor': '#112233'},  // floatingActionButton.focusColor
    <String, dynamic>{'type': 'floatingActionButton', 'focusElevation': 12},  // floatingActionButton.focusElevation
    <String, dynamic>{'type': 'floatingActionButton', 'heroTag': 'x'},  // floatingActionButton.heroTag
    <String, dynamic>{'type': 'floatingActionButton', 'highlightElevation': 12},  // floatingActionButton.highlightElevation
    <String, dynamic>{'type': 'floatingActionButton', 'hoverColor': '#112233'},  // floatingActionButton.hoverColor
    <String, dynamic>{'type': 'floatingActionButton', 'hoverElevation': 12},  // floatingActionButton.hoverElevation
    <String, dynamic>{'type': 'floatingActionButton', 'isExtended': true},  // floatingActionButton.isExtended
    <String, dynamic>{'type': 'floatingActionButton', 'materialTapTargetSize': 'x'},  // floatingActionButton.materialTapTargetSize
    <String, dynamic>{'type': 'floatingActionButton', 'mini': true},  // floatingActionButton.mini
    <String, dynamic>{'type': 'floatingActionButton', 'shape': <String, dynamic>{}},  // floatingActionButton.shape
    <String, dynamic>{'type': 'floatingActionButton', 'splashColor': '#112233'},  // floatingActionButton.splashColor
    <String, dynamic>{'type': 'graph', 'data': 'x', 'labelColor': '#112233'},  // graph.labelColor
    <String, dynamic>{'type': 'grid', 'mainAxisExtent': 12},  // grid.mainAxisExtent
    <String, dynamic>{'type': 'grid', 'maxCrossAxisExtent': 12},  // grid.maxCrossAxisExtent
    <String, dynamic>{'type': 'grid', 'padding': 2},  // grid.padding
    <String, dynamic>{'type': 'grid', 'physics': 'x'},  // grid.physics
    <String, dynamic>{'type': 'grid', 'shrinkWrap': true},  // grid.shrinkWrap
    <String, dynamic>{'type': 'grid', 'spacing': 12},  // grid.spacing
    <String, dynamic>{'type': 'headerBar', 'automaticallyImplyLeading': true},  // headerBar.automaticallyImplyLeading
    <String, dynamic>{'type': 'headerBar', 'bottomHeight': 12},  // headerBar.bottomHeight
    <String, dynamic>{'type': 'headerBar', 'bottomOpacity': 2},  // headerBar.bottomOpacity
    <String, dynamic>{'type': 'headerBar', 'flexibleSpace': <String, dynamic>{'type': 'text', 'content': 'x'}},  // headerBar.flexibleSpace
    <String, dynamic>{'type': 'headerBar', 'shadowColor': '#112233'},  // headerBar.shadowColor
    <String, dynamic>{'type': 'headerBar', 'shape': <String, dynamic>{}},  // headerBar.shape
    <String, dynamic>{'type': 'headerBar', 'toolbarHeight': 12},  // headerBar.toolbarHeight
    <String, dynamic>{'type': 'headerBar', 'toolbarOpacity': 2},  // headerBar.toolbarOpacity
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'cellGap': 12},  // heatmap.cellGap
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'colorScheme': 'x'},  // heatmap.colorScheme
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'columns': 2},  // heatmap.columns
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'maxValue': 2},  // heatmap.maxValue
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'minValue': 2},  // heatmap.minValue
    <String, dynamic>{'type': 'heatmap', 'data': <dynamic>[], 'showLabels': true},  // heatmap.showLabels
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'disabledColor': '#112233'},  // iconButton.disabledColor
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'enableFeedback': true},  // iconButton.enableFeedback
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'fontFamily': 'x'},  // iconButton.fontFamily
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'highlightColor': '#112233'},  // iconButton.highlightColor
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'iconSize': 12},  // iconButton.iconSize
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'padding': 2},  // iconButton.padding
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'splashColor': '#112233'},  // iconButton.splashColor
    <String, dynamic>{'type': 'iconButton', 'icon': 'home', 'splashRadius': 12},  // iconButton.splashRadius
    <String, dynamic>{'type': 'image', 'errorWidget': 'x'},  // image.errorWidget
    <String, dynamic>{'type': 'image', 'fallbackBehavior': 'x'},  // image.fallbackBehavior
    <String, dynamic>{'type': 'image', 'fallbackUrl': 'assets/a.png'},  // image.fallbackUrl
    <String, dynamic>{'type': 'indexedStack', 'children': <dynamic>[], 'clipBehavior': 'x'},  // indexedStack.clipBehavior
    <String, dynamic>{'type': 'indexedStack', 'children': <dynamic>[], 'sizing': 'x'},  // indexedStack.sizing
    <String, dynamic>{'type': 'inkWell', 'autofocus': true},  // inkWell.autofocus
    <String, dynamic>{'type': 'inkWell', 'canRequestFocus': true},  // inkWell.canRequestFocus
    <String, dynamic>{'type': 'inkWell', 'customBorder': <String, dynamic>{}},  // inkWell.customBorder
    <String, dynamic>{'type': 'inkWell', 'enableFeedback': true},  // inkWell.enableFeedback
    <String, dynamic>{'type': 'inkWell', 'excludeFromSemantics': true},  // inkWell.excludeFromSemantics
    <String, dynamic>{'type': 'inkWell', 'focusColor': '#112233'},  // inkWell.focusColor
    <String, dynamic>{'type': 'inkWell', 'highlightColor': '#112233'},  // inkWell.highlightColor
    <String, dynamic>{'type': 'inkWell', 'hoverColor': '#112233'},  // inkWell.hoverColor
    <String, dynamic>{'type': 'inkWell', 'overlayColor': '#112233'},  // inkWell.overlayColor
    <String, dynamic>{'type': 'inkWell', 'splashColor': '#112233'},  // inkWell.splashColor
    <String, dynamic>{'type': 'inkWell', 'splashRadius': 12},  // inkWell.splashRadius
    <String, dynamic>{'type': 'intrinsicWidth', 'stepHeight': 12},  // intrinsicWidth.stepHeight
    <String, dynamic>{'type': 'intrinsicWidth', 'stepWidth': 12},  // intrinsicWidth.stepWidth
    <String, dynamic>{'type': 'lazy', 'delay': 2},  // lazy.delay
    <String, dynamic>{'type': 'linear', 'children': <dynamic>[], 'padding': 2},  // linear.padding
    <String, dynamic>{'type': 'linear', 'children': <dynamic>[], 'wrap': true},  // linear.wrap
    <String, dynamic>{'type': 'list', 'itemBuilder': <String, dynamic>{'type': 'text', 'content': 'x'}},  // list.itemBuilder
    <String, dynamic>{'type': 'list', 'itemCount': 2},  // list.itemCount
    <String, dynamic>{'type': 'list', 'padding': 2},  // list.padding
    <String, dynamic>{'type': 'list', 'physics': 'x'},  // list.physics
    <String, dynamic>{'type': 'list', 'scrollCacheExtent': 12},  // list.scrollCacheExtent
    <String, dynamic>{'type': 'list', 'shrinkWrap': true},  // list.shrinkWrap
    <String, dynamic>{'type': 'listItem', 'contentPadding': 2},  // listItem.contentPadding
    <String, dynamic>{'type': 'listItem', 'dense': true},  // listItem.dense
    <String, dynamic>{'type': 'listItem', 'focusColor': '#112233'},  // listItem.focusColor
    <String, dynamic>{'type': 'listItem', 'hoverColor': '#112233'},  // listItem.hoverColor
    <String, dynamic>{'type': 'listItem', 'iconColor': '#112233'},  // listItem.iconColor
    <String, dynamic>{'type': 'listItem', 'isThreeLine': true},  // listItem.isThreeLine
    <String, dynamic>{'type': 'listItem', 'selectedTileColor': '#112233'},  // listItem.selectedTileColor
    <String, dynamic>{'type': 'listItem', 'shape': <String, dynamic>{}},  // listItem.shape
    <String, dynamic>{'type': 'listItem', 'tileColor': '#112233'},  // listItem.tileColor
    <String, dynamic>{'type': 'lottieAnimation', 'fit': 'x'},  // lottieAnimation.fit
    <String, dynamic>{'type': 'lottieAnimation', 'height': 12},  // lottieAnimation.height
    <String, dynamic>{'type': 'lottieAnimation', 'speed': 2},  // lottieAnimation.speed
    <String, dynamic>{'type': 'map', 'height': 12},  // map.height
    <String, dynamic>{'type': 'map', 'interactive': true},  // map.interactive
    <String, dynamic>{'type': 'map', 'markerColor': '#112233'},  // map.markerColor
    <String, dynamic>{'type': 'map', 'showCoordinates': true},  // map.showCoordinates
    <String, dynamic>{'type': 'map', 'showGrid': true},  // map.showGrid
    <String, dynamic>{'type': 'mediaPlayer', 'accentColor': '#112233'},  // mediaPlayer.accentColor
    <String, dynamic>{'type': 'mediaPlayer', 'controlsColor': '#112233'},  // mediaPlayer.controlsColor
    <String, dynamic>{'type': 'navigationRail', 'extended': true},  // navigationRail.extended
    <String, dynamic>{'type': 'navigationRail', 'groupAlignment': 2},  // navigationRail.groupAlignment
    <String, dynamic>{'type': 'navigationRail', 'labelType': 'x'},  // navigationRail.labelType
    <String, dynamic>{'type': 'navigationRail', 'minExtendedWidth': 12},  // navigationRail.minExtendedWidth
    <String, dynamic>{'type': 'navigationRail', 'minWidth': 12},  // navigationRail.minWidth
    <String, dynamic>{'type': 'navigationRail', 'selectedIconTheme': <String, dynamic>{}},  // navigationRail.selectedIconTheme
    <String, dynamic>{'type': 'navigationRail', 'selectedLabelTextStyle': <String, dynamic>{'fontSize': 12}},  // navigationRail.selectedLabelTextStyle
    <String, dynamic>{'type': 'navigationRail', 'unselectedIconTheme': <String, dynamic>{}},  // navigationRail.unselectedIconTheme
    <String, dynamic>{'type': 'navigationRail', 'unselectedLabelTextStyle': <String, dynamic>{'fontSize': 12}},  // navigationRail.unselectedLabelTextStyle
    <String, dynamic>{'type': 'networkGraph', 'edgeColor': '#112233'},  // networkGraph.edgeColor
    <String, dynamic>{'type': 'networkGraph', 'edges': <dynamic>[]},  // networkGraph.edges
    <String, dynamic>{'type': 'networkGraph', 'height': 12},  // networkGraph.height
    <String, dynamic>{'type': 'networkGraph', 'interactive': true},  // networkGraph.interactive
    <String, dynamic>{'type': 'networkGraph', 'labelColor': '#112233'},  // networkGraph.labelColor
    <String, dynamic>{'type': 'networkGraph', 'layout': 'x'},  // networkGraph.layout
    <String, dynamic>{'type': 'networkGraph', 'nodeColor': '#112233'},  // networkGraph.nodeColor
    <String, dynamic>{'type': 'networkGraph', 'nodes': <dynamic>[]},  // networkGraph.nodes
    <String, dynamic>{'type': 'numberField', 'error': 'x'},  // numberField.error
    <String, dynamic>{'type': 'numberStepper', 'size': 'small'},  // numberStepper.size
    <String, dynamic>{'type': 'pageView', 'children': <dynamic>[], 'clipBehavior': 'x'},  // pageView.clipBehavior
    <String, dynamic>{'type': 'pageView', 'children': <dynamic>[], 'padEnds': true},  // pageView.padEnds
    <String, dynamic>{'type': 'pageView', 'children': <dynamic>[], 'pageSnapping': true},  // pageView.pageSnapping
    <String, dynamic>{'type': 'pagination', 'total': 2, 'current': 2},  // pagination.current
    <String, dynamic>{'type': 'pdfViewer', 'src': 'assets/a.png', 'height': 12},  // pdfViewer.height
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'iconSize': 12},  // popupMenuButton.iconSize
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'offset': <String, dynamic>{}},  // popupMenuButton.offset
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'padding': 2},  // popupMenuButton.padding
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'shadowColor': '#112233'},  // popupMenuButton.shadowColor
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'shape': <String, dynamic>{}},  // popupMenuButton.shape
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'splashRadius': 12},  // popupMenuButton.splashRadius
    <String, dynamic>{'type': 'popupMenuButton', 'items': <dynamic>[], 'surfaceTintColor': '#112233'},  // popupMenuButton.surfaceTintColor
    <String, dynamic>{'type': 'positioned', 'height': 12},  // positioned.height
    <String, dynamic>{'type': 'progressBar', 'size': 12},  // progressBar.size
    <String, dynamic>{'type': 'progressBar', 'strokeWidth': 12},  // progressBar.strokeWidth
    <String, dynamic>{'type': 'radio', 'value': 'x', 'groupValue': 'x', 'activeColor': '#112233'},  // radio.activeColor
    <String, dynamic>{'type': 'radio', 'value': 'x', 'groupValue': 'x', 'focusColor': '#112233'},  // radio.focusColor
    <String, dynamic>{'type': 'radio', 'value': 'x', 'groupValue': 'x', 'hoverColor': '#112233'},  // radio.hoverColor
    <String, dynamic>{'type': 'radio', 'value': 'x', 'groupValue': 'x', 'splashRadius': 12},  // radio.splashRadius
    <String, dynamic>{'type': 'rangeSlider', 'activeColor': '#112233'},  // rangeSlider.activeColor
    <String, dynamic>{'type': 'rangeSlider', 'inactiveColor': '#112233'},  // rangeSlider.inactiveColor
    <String, dynamic>{'type': 'rangeSlider', 'labels': <dynamic>[]},  // rangeSlider.labels
    <String, dynamic>{'type': 'rating', 'allowHalf': true},  // rating.allowHalf
    <String, dynamic>{'type': 'rating', 'emptyColor': '#112233'},  // rating.emptyColor
    <String, dynamic>{'type': 'rating', 'readOnly': true},  // rating.readOnly
    <String, dynamic>{'type': 'rating', 'size': 12},  // rating.size
    <String, dynamic>{'type': 'richText', 'spans': <dynamic>[], 'textScaleFactor': 2},  // richText.textScaleFactor
    <String, dynamic>{'type': 'safeArea', 'maintainBottomViewPadding': true},  // safeArea.maintainBottomViewPadding
    <String, dynamic>{'type': 'safeArea', 'minimum': 2},  // safeArea.minimum
    <String, dynamic>{'type': 'scrollView', 'primary': true},  // scrollView.primary
    <String, dynamic>{'type': 'select', 'disabledHint': 'x'},  // select.disabledHint
    <String, dynamic>{'type': 'select', 'iconSize': 12},  // select.iconSize
    <String, dynamic>{'type': 'select', 'isExpanded': true},  // select.isExpanded
    <String, dynamic>{'type': 'select', 'itemHeight': 12},  // select.itemHeight
    <String, dynamic>{'type': 'select', 'style': <String, dynamic>{'fontSize': 12}},  // select.style
    <String, dynamic>{'type': 'signature', 'borderWidth': 12},  // signature.borderWidth
    <String, dynamic>{'type': 'simpleDialog', 'contentPadding': 2},  // simpleDialog.contentPadding
    <String, dynamic>{'type': 'simpleDialog', 'shape': <String, dynamic>{}},  // simpleDialog.shape
    <String, dynamic>{'type': 'simpleDialog', 'titlePadding': 2},  // simpleDialog.titlePadding
    <String, dynamic>{'type': 'singleChildScrollView', 'clipBehavior': 'x'},  // singleChildScrollView.clipBehavior
    <String, dynamic>{'type': 'singleChildScrollView', 'physics': 'x'},  // singleChildScrollView.physics
    <String, dynamic>{'type': 'singleChildScrollView', 'primary': true},  // singleChildScrollView.primary
    <String, dynamic>{'type': 'slider', 'activeColor': '#112233'},  // slider.activeColor
    <String, dynamic>{'type': 'slider', 'inactiveColor': '#112233'},  // slider.inactiveColor
    <String, dynamic>{'type': 'slider', 'thumbColor': '#112233'},  // slider.thumbColor
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'behavior': 'x'},  // snackBar.behavior
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'closeIconColor': '#112233'},  // snackBar.closeIconColor
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'dismissDirection': 'x'},  // snackBar.dismissDirection
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'margin': 2},  // snackBar.margin
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'padding': 2},  // snackBar.padding
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'shape': <String, dynamic>{}},  // snackBar.shape
    <String, dynamic>{'type': 'snackBar', 'content': 'x', 'showCloseIcon': true},  // snackBar.showCloseIcon
    <String, dynamic>{'type': 'stack', 'children': <dynamic>[], 'clipBehavior': 'x'},  // stack.clipBehavior
    <String, dynamic>{'type': 'stepper', 'steps': <dynamic>[], 'margin': 2},  // stepper.margin
    <String, dynamic>{'type': 'stepper', 'steps': <dynamic>[], 'physics': 'x'},  // stepper.physics
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'enableFeedback': true},  // tabBar.enableFeedback
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'indicator': <String, dynamic>{}},  // tabBar.indicator
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'indicatorPadding': 2},  // tabBar.indicatorPadding
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'indicatorSize': 'x'},  // tabBar.indicatorSize
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'indicatorWeight': 12},  // tabBar.indicatorWeight
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'isScrollable': true},  // tabBar.isScrollable
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'labelColor': '#112233'},  // tabBar.labelColor
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'labelPadding': 2},  // tabBar.labelPadding
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'mouseCursor': 'x'},  // tabBar.mouseCursor
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'overlayColor': '#112233'},  // tabBar.overlayColor
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'padding': 2},  // tabBar.padding
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'physics': 'x'},  // tabBar.physics
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'unselectedLabelColor': '#112233'},  // tabBar.unselectedLabelColor
    <String, dynamic>{'type': 'tabBar', 'tabs': <dynamic>[], 'unselectedLabelStyle': <String, dynamic>{'fontSize': 12}},  // tabBar.unselectedLabelStyle
    <String, dynamic>{'type': 'tabBarView', 'children': <dynamic>[], 'dragStartBehavior': 'x'},  // tabBarView.dragStartBehavior
    <String, dynamic>{'type': 'tabBarView', 'children': <dynamic>[], 'physics': 'x'},  // tabBarView.physics
    <String, dynamic>{'type': 'table', 'rows': <dynamic>[], 'textBaseline': 'x'},  // table.textBaseline
    <String, dynamic>{'type': 'text', 'ariaLabel': 'x'},  // text.ariaLabel
    <String, dynamic>{'type': 'text', 'semanticsLabel': 'x'},  // text.semanticsLabel
    <String, dynamic>{'type': 'text', 'softWrap': true},  // text.softWrap
    <String, dynamic>{'type': 'text', 'textScaleFactor': 2},  // text.textScaleFactor
    <String, dynamic>{'type': 'text', 'textTransform': 'x'},  // text.textTransform
    <String, dynamic>{'type': 'textInput', 'debounce': 2},  // textInput.debounce
    <String, dynamic>{'type': 'textInput', 'errorText': 'x'},  // textInput.errorText
    <String, dynamic>{'type': 'textInput', 'style': <String, dynamic>{'fontSize': 12}},  // textInput.style
    <String, dynamic>{'type': 'textInput', 'textInputAction': 'x'},  // textInput.textInputAction
    <String, dynamic>{'type': 'timeField', 'errorText': 'x'},  // timeField.errorText
    <String, dynamic>{'type': 'timePicker', 'initialTime': 'x'},  // timePicker.initialTime
    <String, dynamic>{'type': 'timeline', 'items': <dynamic>[], 'lineWidth': 12},  // timeline.lineWidth
    <String, dynamic>{'type': 'timeline', 'items': <dynamic>[], 'nodeSize': 12},  // timeline.nodeSize
    <String, dynamic>{'type': 'timeline', 'items': <dynamic>[], 'spacing': 12},  // timeline.spacing
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'enableFeedback': true},  // tooltip.enableFeedback
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'excludeFromSemantics': true},  // tooltip.excludeFromSemantics
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'height': 12},  // tooltip.height
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'margin': 2},  // tooltip.margin
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'padding': 2},  // tooltip.padding
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'preferBelow': true},  // tooltip.preferBelow
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'richMessage': <dynamic>[]},  // tooltip.richMessage
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'showDuration': 2},  // tooltip.showDuration
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'textStyle': <String, dynamic>{'fontSize': 12}},  // tooltip.textStyle
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'triggerMode': 'x'},  // tooltip.triggerMode
    <String, dynamic>{'type': 'tooltip', 'message': 'x', 'verticalOffset': 12},  // tooltip.verticalOffset
    <String, dynamic>{'type': 'visibility', 'maintainAnimation': true},  // visibility.maintainAnimation
    <String, dynamic>{'type': 'visibility', 'maintainInteractivity': true},  // visibility.maintainInteractivity
    <String, dynamic>{'type': 'wrap', 'children': <dynamic>[], 'clipBehavior': 'x'},  // wrap.clipBehavior
    <String, dynamic>{'type': 'wrap', 'children': <dynamic>[], 'runAlignment': 'x'},  // wrap.runAlignment
    <String, dynamic>{'type': 'wrap', 'children': <dynamic>[], 'verticalDirection': 'x'},  // wrap.verticalDirection
  ];

  test('every promoted property is declared and accepted at its type', () {
    final rejected = <String>[];
    for (final doc in cases) {
      final r = validateMcpUiDslWidget(doc);
      if (!r.isValid) {
        final extra = doc.keys.where((k) => k != 'type').join(',');
        rejected.add('${doc['type']} [$extra]: ${r.errors.take(1).join()}');
      }
    }
    expect(rejected, isEmpty,
        reason: '${rejected.length} of ${cases.length} promoted properties '
            'do not validate at the type they were declared with:\n'
            '${rejected.take(12).join('\n')}');
  });

  test('the promoted set is not empty and covers the widgets it claims', () {
    expect(cases.length, greaterThanOrEqualTo(300));
    expect(cases.map((c) => c['type']).toSet().length, greaterThanOrEqualTo(70));
  });
}
