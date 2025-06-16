import 'widget_registry.dart';

// Layout widgets
import '../widgets/layout/column_factory.dart';
import '../widgets/layout/row_factory.dart';
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
import '../widgets/input/stepper_factory.dart';
import '../widgets/input/datepicker_factory.dart';
import '../widgets/input/timepicker_factory.dart';
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
import '../widgets/scroll/pageview_factory.dart';
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


/// Default widget registration
class DefaultWidgets {
  /// Register all default widgets
  static void registerAll(WidgetRegistry registry) {
    // Layout widgets
    registry.register('column', ColumnWidgetFactory());
    registry.register('row', RowWidgetFactory());
    registry.register('stack', StackWidgetFactory());
    registry.register('container', ContainerWidgetFactory());
    registry.register('center', CenterWidgetFactory());
    registry.register('align', AlignWidgetFactory());
    registry.register('padding', PaddingWidgetFactory());
    registry.register('sizedbox', SizedBoxWidgetFactory());
    registry.register('expanded', ExpandedWidgetFactory());
    registry.register('flexible', FlexibleWidgetFactory());
    registry.register('spacer', SpacerWidgetFactory());
    registry.register('wrap', WrapWidgetFactory());
    registry.register('positioned', PositionedWidgetFactory());
    registry.register('intrinsicheight', IntrinsicHeightWidgetFactory());
    registry.register('intrinsicwidth', IntrinsicWidthWidgetFactory());
    registry.register('visibility', VisibilityWidgetFactory());
    registry.register('aspectratio', AspectRatioWidgetFactory());
    registry.register('baseline', BaselineWidgetFactory());
    registry.register('constrainedbox', ConstrainedBoxWidgetFactory());
    registry.register('fittedbox', FittedBoxWidgetFactory());
    registry.register('limitedbox', LimitedBoxWidgetFactory());
    registry.register('conditional', ConditionalFactory());

    // Display widgets
    registry.register('text', TextWidgetFactory());
    registry.register('richtext', RichTextWidgetFactory());
    registry.register('image', ImageWidgetFactory());
    registry.register('icon', IconWidgetFactory());
    registry.register('card', CardWidgetFactory());
    registry.register('divider', DividerWidgetFactory());
    registry.register('badge', BadgeWidgetFactory());
    registry.register('chip', ChipWidgetFactory());
    registry.register('avatar', AvatarWidgetFactory());
    registry.register('circleAvatar', AvatarWidgetFactory());
    registry.register('tooltip', TooltipWidgetFactory());
    registry.register('placeholder', PlaceholderWidgetFactory());
    registry.register('banner', BannerWidgetFactory());
    registry.register('clipoval', ClipOvalWidgetFactory());
    registry.register('cliprrect', ClipRRectWidgetFactory());
    registry.register('decoratedbox', DecoratedBoxWidgetFactory());
    
    // Progress indicators (create new factories for these)
    registry.register('circularprogressindicator', CircularProgressWidgetFactory());
    registry.register('linearprogressindicator', LinearProgressWidgetFactory());
    registry.register('progressindicator', ProgressWidgetFactory());

    // Input widgets
    registry.register('button', ButtonWidgetFactory());
    registry.register('textfield', TextFieldWidgetFactory());
    registry.register('textformfield', TextFormFieldWidgetFactory());
    registry.register('checkbox', CheckboxWidgetFactory());
    registry.register('radio', RadioWidgetFactory());
    registry.register('switch', SwitchWidgetFactory());
    registry.register('slider', SliderWidgetFactory());
    registry.register('rangeslider', RangeSliderWidgetFactory());
    registry.register('dropdown', DropdownWidgetFactory());
    registry.register('stepper', StepperWidgetFactory());
    registry.register('datepicker', DatePickerWidgetFactory());
    registry.register('timepicker', TimePickerWidgetFactory());
    
    // IconButton (create new factory)
    registry.register('iconbutton', IconButtonWidgetFactory());
    
    // Form (create new factory)
    registry.register('form', FormWidgetFactory());
    
    // Number field
    registry.register('numberField', NumberFieldFactory());
    registry.register('numberfield', NumberFieldFactory()); // Alternative naming
    
    // Color picker
    registry.register('colorPicker', ColorPickerFactory());
    registry.register('colorpicker', ColorPickerFactory()); // Alternative naming
    
    // Radio group
    registry.register('radioGroup', RadioGroupFactory());
    registry.register('radiogroup', RadioGroupFactory()); // Alternative naming
    
    // Checkbox group
    registry.register('checkboxGroup', CheckboxGroupFactory());
    registry.register('checkboxgroup', CheckboxGroupFactory()); // Alternative naming
    
    // Segmented control
    registry.register('segmentedControl', SegmentedControlFactory());
    registry.register('segmentedcontrol', SegmentedControlFactory()); // Alternative naming
    
    // Date and time fields
    registry.register('dateField', DateFieldFactory());
    registry.register('datefield', DateFieldFactory()); // Alternative naming
    registry.register('timeField', TimeFieldFactory());
    registry.register('timefield', TimeFieldFactory()); // Alternative naming
    registry.register('dateRangePicker', DateRangePickerFactory());
    registry.register('daterangepicker', DateRangePickerFactory()); // Alternative naming

    // List widgets
    registry.register('listview', ListViewWidgetFactory());
    registry.register('gridview', GridViewWidgetFactory());
    registry.register('listtile', ListTileWidgetFactory());

    // Navigation widgets
    registry.register('appbar', AppBarWidgetFactory());
    registry.register('tabbar', TabBarWidgetFactory());
    registry.register('drawer', DrawerWidgetFactory());
    registry.register('bottomnavigationbar', BottomNavigationBarWidgetFactory());
    registry.register('navigationrail', NavigationRailWidgetFactory());
    registry.register('floatingactionbutton', FloatingActionButtonWidgetFactory());
    registry.register('popupmenubutton', PopupMenuButtonWidgetFactory());
    
    // TabBarView (create new factory)
    registry.register('tabbarview', TabBarViewWidgetFactory());

    // Scroll widgets
    registry.register('singlechildscrollview', SingleChildScrollViewWidgetFactory());
    registry.register('pageview', PageViewWidgetFactory());
    registry.register('scrollView', ScrollViewFactory());
    registry.register('scrollview', ScrollViewFactory()); // Alternative naming
    
    // Scrollbar (create new factory)
    registry.register('scrollbar', ScrollbarWidgetFactory());

    // Animation widgets
    registry.register('animatedcontainer', AnimatedContainerWidgetFactory());

    // Interactive widgets
    registry.register('gesturedetector', GestureDetectorWidgetFactory());
    registry.register('inkwell', InkWellWidgetFactory());
    registry.register('draggable', DraggableFactory());
    registry.register('dragtarget', DragTargetFactory());
    registry.register('dragTarget', DragTargetFactory()); // Alternative naming

    // Dialog widgets
    registry.register('alertdialog', AlertDialogWidgetFactory());
    registry.register('snackbar', SnackBarWidgetFactory());
    registry.register('bottomsheet', BottomSheetWidgetFactory());
    
    // Additional missing widgets
    registry.register('verticaldivider', VerticalDividerWidgetFactory());
    registry.register('table', TableWidgetFactory());
    registry.register('flow', FlowWidgetFactory());
    registry.register('margin', MarginWidgetFactory());
    registry.register('decoration', DecorationWidgetFactory());
  }
}