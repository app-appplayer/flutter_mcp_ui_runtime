import 'widget_registry.dart';

// Layout widgets
import '../widgets/layout/linear_factory.dart';
import '../widgets/layout/stack_factory.dart';
import '../widgets/layout/container_factory.dart';
import '../widgets/layout/center_factory.dart';
import '../widgets/layout/align_factory.dart';
import '../widgets/layout/padding_factory.dart';
import '../widgets/layout/sizedbox_factory.dart';
import '../widgets/layout/expanded_factory.dart';
import '../widgets/layout/flexible_factory.dart';
import '../widgets/layout/spacer_factory.dart';
import '../widgets/layout/wrap_factory.dart';
import '../widgets/layout/positioned_factory.dart';
import '../widgets/layout/intrinsicheight_factory.dart';
import '../widgets/layout/intrinsicwidth_factory.dart';
import '../widgets/layout/visibility_factory.dart';
import '../widgets/layout/aspectratio_factory.dart';
import '../widgets/layout/baseline_factory.dart';
import '../widgets/layout/constrainedbox_factory.dart';
import '../widgets/layout/fittedbox_factory.dart';
import '../widgets/layout/limitedbox_factory.dart';
import '../widgets/layout/conditional_factory.dart';

// Display widgets
import '../widgets/display/text_factory.dart';
import '../widgets/display/richtext_factory.dart';
import '../widgets/display/image_factory.dart';
import '../widgets/display/icon_factory.dart';
import '../widgets/display/card_factory.dart';
import '../widgets/display/divider_factory.dart';
import '../widgets/display/badge_factory.dart';
import '../widgets/display/chip_factory.dart';
import '../widgets/display/avatar_factory.dart';
import '../widgets/display/tooltip_factory.dart';
import '../widgets/display/placeholder_factory.dart';
import '../widgets/display/banner_factory.dart';
import '../widgets/display/clipoval_factory.dart';
import '../widgets/display/cliprrect_factory.dart';
import '../widgets/display/decoratedbox_factory.dart';
import '../widgets/display/progress_factory.dart';
import '../widgets/display/verticaldivider_factory.dart';
import '../widgets/display/decoration_factory.dart';

// Layout widgets (additional)
import '../widgets/layout/table_factory.dart';
import '../widgets/layout/flow_factory.dart';
import '../widgets/layout/margin_factory.dart';

// Input widgets
import '../widgets/input/button_factory.dart';
import '../widgets/input/textfield_factory.dart';
import '../widgets/input/textformfield_factory.dart';
import '../widgets/input/checkbox_factory.dart';
import '../widgets/input/radio_factory.dart';
import '../widgets/input/switch_factory.dart';
import '../widgets/input/slider_factory.dart';
import '../widgets/input/rangeslider_factory.dart';
import '../widgets/input/dropdown_factory.dart';
import '../widgets/input/iconbutton_factory.dart';
import '../widgets/input/form_factory.dart';
import '../widgets/input/number_field_factory.dart';
import '../widgets/input/color_picker_factory.dart';
import '../widgets/input/radio_group_factory.dart';
import '../widgets/input/checkbox_group_factory.dart';
import '../widgets/input/segmented_control_factory.dart';
import '../widgets/input/date_field_factory.dart';
import '../widgets/input/time_field_factory.dart';
import '../widgets/input/date_range_picker_factory.dart';

// List widgets
import '../widgets/list/listview_factory.dart';
import '../widgets/list/gridview_factory.dart';
import '../widgets/list/listtile_factory.dart';

// Navigation widgets
import '../widgets/navigation/appbar_factory.dart';
import '../widgets/navigation/tabbar_factory.dart';
import '../widgets/navigation/drawer_factory.dart';
import '../widgets/navigation/bottomnavigationbar_factory.dart';
import '../widgets/navigation/navigationrail_factory.dart';
import '../widgets/navigation/floatingactionbutton_factory.dart';
import '../widgets/navigation/popupmenubutton_factory.dart';
import '../widgets/navigation/tabbarview_factory.dart';

// Scroll widgets
import '../widgets/scroll/singlechildscrollview_factory.dart';
import '../widgets/scroll/scrollbar_factory.dart';
import '../widgets/scroll/scroll_view_factory.dart';

// Animation widgets
import '../widgets/animation/animatedcontainer_factory.dart';

// Interactive widgets
import '../widgets/interactive/gesturedetector_factory.dart';
import '../widgets/interactive/inkwell_factory.dart';
import '../widgets/interactive/draggable_factory.dart';
import '../widgets/interactive/drag_target_factory.dart';

// Dialog widgets
import '../widgets/dialog/alertdialog_factory.dart';
import '../widgets/dialog/snackbar_factory.dart';
import '../widgets/dialog/bottomsheet_factory.dart';

// Advanced widgets
import '../widgets/advanced/chart_factory.dart';
import '../widgets/advanced/map_factory.dart';
import '../widgets/advanced/media_player_factory.dart';
import '../widgets/advanced/calendar_factory.dart';
import '../widgets/advanced/tree_factory.dart';
import '../widgets/advanced/timeline_factory.dart';
import '../widgets/advanced/gauge_factory.dart';
import '../widgets/advanced/heatmap_factory.dart';
import '../widgets/advanced/graph_factory.dart';

// Accessibility widgets
import '../widgets/accessibility/accessible_wrapper_factory.dart';

/// Default widget registration
class DefaultWidgets {
  /// Register all default widgets
  static void registerAll(WidgetRegistry registry) {
    // Layout widgets - Spec v1.0 names
    registry.register('linear', LinearLayoutFactory()); // New spec v1.0
    registry.register(
        'box', ContainerWidgetFactory()); // Spec v1.0: box = container

    // Core spec v1.0 layout widgets

    // Common layout widgets
    registry.register('stack', StackWidgetFactory());
    registry.register('center', CenterWidgetFactory());
    registry.register('align', AlignWidgetFactory());
    registry.register('padding', PaddingWidgetFactory());
    registry.register('sizedBox', SizedBoxWidgetFactory()); // CamelCase
    registry.register('expanded', ExpandedWidgetFactory());
    registry.register('flexible', FlexibleWidgetFactory());
    registry.register('spacer', SpacerWidgetFactory());
    registry.register('wrap', WrapWidgetFactory());
    registry.register('positioned', PositionedWidgetFactory());
    registry.register(
        'intrinsicHeight', IntrinsicHeightWidgetFactory()); // CamelCase
    registry.register(
        'intrinsicWidth', IntrinsicWidthWidgetFactory()); // CamelCase
    registry.register('visibility', VisibilityWidgetFactory());
    registry.register('aspectRatio', AspectRatioWidgetFactory()); // CamelCase
    registry.register('baseline', BaselineWidgetFactory());
    registry.register(
        'constrainedBox', ConstrainedBoxWidgetFactory()); // CamelCase
    registry.register('fittedBox', FittedBoxWidgetFactory()); // CamelCase
    registry.register('limitedBox', LimitedBoxWidgetFactory()); // CamelCase
    registry.register('conditional', ConditionalFactory()); // MCP UI DSL v1.0

    // Display widgets
    registry.register('text', TextWidgetFactory());
    registry.register('richText', RichTextWidgetFactory()); // CamelCase
    registry.register('image', ImageWidgetFactory());
    registry.register('icon', IconWidgetFactory());
    registry.register('card', CardWidgetFactory());
    registry.register('divider', DividerWidgetFactory());
    registry.register('badge', BadgeWidgetFactory());
    registry.register('chip', ChipWidgetFactory());
    registry.register('avatar', AvatarWidgetFactory());
    // circleAvatar is an alias for avatar - removed for spec compliance
    registry.register('tooltip', TooltipWidgetFactory());
    registry.register('placeholder', PlaceholderWidgetFactory());
    registry.register('banner', BannerWidgetFactory());
    registry.register('clipOval', ClipOvalWidgetFactory()); // CamelCase
    registry.register('clipRRect', ClipRRectWidgetFactory()); // CamelCase
    registry.register('decoratedBox', DecoratedBoxWidgetFactory()); // CamelCase

    // Progress indicators - MCP UI DSL v1.0 uses CamelCase
    registry.register('loadingIndicator', ProgressWidgetFactory());
    registry.register('progressBar',
        ProgressWidgetFactory()); // Also register progressBar for v1.0 spec

    // Input widgets - Spec v1.0 names
    registry.register(
        'textInput', TextFieldWidgetFactory()); // CamelCase per spec
    registry.register(
        'switch', SwitchWidgetFactory()); // Spec v1.0: switch not toggle
    registry.register('select', DropdownWidgetFactory()); // Spec v1.0

    // Common input widgets
    registry.register('button', ButtonWidgetFactory());
    registry.register('checkbox', CheckboxWidgetFactory());
    registry.register('radio', RadioWidgetFactory());
    registry.register('slider', SliderWidgetFactory());
    registry.register('rangeSlider', RangeSliderWidgetFactory()); // CamelCase

    // Additional input widgets
    registry.register(
        'textFormField', TextFormFieldWidgetFactory()); // CamelCase

    // Additional input widgets
    registry.register('iconButton', IconButtonWidgetFactory()); // CamelCase
    registry.register('form', FormWidgetFactory());

    // Extended input widgets - CamelCase per spec
    registry.register('numberField', NumberFieldFactory());
    registry.register('colorPicker', ColorPickerFactory());
    registry.register('radioGroup', RadioGroupFactory());
    registry.register('checkboxGroup', CheckboxGroupFactory());
    registry.register('segmentedControl', SegmentedControlFactory());
    registry.register('dateField', DateFieldFactory());
    registry.register('timeField', TimeFieldFactory());
    registry.register('dateRangePicker', DateRangePickerFactory());

    // List widgets - spec v1.0 names
    registry.register('list', ListViewWidgetFactory());
    registry.register('listView',
        ListViewWidgetFactory()); // Also register listView for v1.0 spec
    registry.register('grid', GridViewWidgetFactory());
    registry.register('listTile', ListTileWidgetFactory()); // CamelCase

    // Navigation widgets - Spec v1.0 names
    registry.register('headerBar', AppBarWidgetFactory()); // CamelCase per spec
    registry.register('bottomNav',
        BottomNavigationBarWidgetFactory()); // Spec v1.0: bottomNav
    registry.register('bottomNavigation',
        BottomNavigationBarWidgetFactory()); // Also register bottomNavigation

    // Common navigation widgets
    registry.register('tabBar', TabBarWidgetFactory()); // CamelCase
    registry.register('drawer', DrawerWidgetFactory());
    registry.register(
        'navigationRail', NavigationRailWidgetFactory()); // CamelCase
    registry.register('floatingActionButton',
        FloatingActionButtonWidgetFactory()); // CamelCase
    registry.register(
        'popupMenuButton', PopupMenuButtonWidgetFactory()); // CamelCase
    registry.register('tabBarView', TabBarViewWidgetFactory()); // CamelCase

    // Scroll widgets
    registry.register('scrollView', ScrollViewFactory()); // CamelCase per spec
    registry.register('singleChildScrollView',
        SingleChildScrollViewWidgetFactory()); // CamelCase
    registry.register('scrollBar', ScrollbarWidgetFactory()); // CamelCase

    // Animation widgets
    registry.register(
        'animatedContainer', AnimatedContainerWidgetFactory()); // CamelCase

    // Interactive widgets
    registry.register(
        'gestureDetector', GestureDetectorWidgetFactory()); // CamelCase
    registry.register('inkWell', InkWellWidgetFactory()); // CamelCase
    registry.register('draggable', DraggableFactory());
    registry.register('dragTarget', DragTargetFactory()); // CamelCase

    // Dialog widgets
    registry.register('alertDialog', AlertDialogWidgetFactory()); // CamelCase
    registry.register('snackBar', SnackBarWidgetFactory()); // CamelCase
    registry.register('bottomSheet', BottomSheetWidgetFactory()); // CamelCase

    // Additional display widgets
    registry.register(
        'verticalDivider', VerticalDividerWidgetFactory()); // CamelCase
    registry.register('decoration', DecorationWidgetFactory());

    // Additional layout widgets
    registry.register('table', TableWidgetFactory());
    registry.register('flow', FlowWidgetFactory());
    registry.register('margin', MarginWidgetFactory());

    // Advanced widgets - Spec v1.0
    registry.register('chart', ChartWidgetFactory());
    registry.register('map', MapWidgetFactory());
    registry.register(
        'mediaPlayer', MediaPlayerWidgetFactory()); // CamelCase per spec
    registry.register('calendar', CalendarWidgetFactory());
    registry.register('tree', TreeWidgetFactory());
    registry.register('timeline', TimelineWidgetFactory());
    registry.register('gauge', GaugeWidgetFactory());
    registry.register('heatmap', HeatmapWidgetFactory());
    registry.register('graph', GraphWidgetFactory());

    // Accessibility widgets
    registry.register('accessibleWrapper', AccessibleWrapperFactory());

    // Legacy aliases for backward compatibility
    registry.register('container', ContainerWidgetFactory());
    registry.register(
        'column', LinearLayoutFactory()); // Column = vertical linear
    registry.register('row', LinearLayoutFactory()); // Row = horizontal linear
    registry.register('toggle', SwitchWidgetFactory()); // Toggle = switch
    registry.register('textfield', TextFieldWidgetFactory());
    registry.register('dropdown', DropdownWidgetFactory());
    registry.register('listview', ListViewWidgetFactory());
    registry.register('gridview', GridViewWidgetFactory());
    registry.register('appbar', AppBarWidgetFactory());
    registry.register(
        'bottomnavigationbar', BottomNavigationBarWidgetFactory());
  }
}
