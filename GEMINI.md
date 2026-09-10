# Mobile Android Screen Typography & Layout Rules

When designing or modifying Flutter UI in this project:

## Target Device Profile & Constraints
1. **Target Viewport**:
   - The primary deployment target is an Android APK running on standard portrait mobile displays (360dp to 412dp screen width, ~700dp to 900dp screen height).
   - Yellow/black striped overflow banners (`A RenderFlex overflowed...`) are strictly prohibited.

## Typography Sizing Boundaries
1. **Never use oversize font sizes inside constrained card/column layouts**:
   - Inside multi-column cards (e.g. 2-column or 3-column metric grids), metric values MUST NOT exceed `fontSize: 36` to `38`. Font sizes of 48+ or 58+ will reliably blow past the vertical and horizontal boundaries when accompanied by labels and units.
   - Screen headers or top titles displayed alongside status badges/actions in a horizontal `Row` MUST NOT exceed `fontSize: 24` to `26`.
   - Card labels, unit tags, and helper descriptions should remain between `9` and `12` px.

2. **Mandatory Overflow Prevention on Dynamic and Wrapped Text**:
   - Always wrap large metric text widgets in `FittedBox(fit: BoxFit.scaleDown, child: Text(...))` so that multi-digit values or wide glyphs scale gracefully without overflowing.
   - Any dynamic or clinical summary text (such as `metrics.limpingSummary` or status descriptions) that could span multiple words must provide `maxLines`, `overflow: TextOverflow.ellipsis`, or be wrapped in `FittedBox(fit: BoxFit.scaleDown)` when placed in bounded containers.

3. **Row and Column Layout Constraints**:
   - In any `Row` containing both title/content and a right-aligned widget (like a badge, icon, or button), wrap the title or expanding widget in `Expanded` or `Flexible`. Never let an unconstrained `Column` with large text sit beside another widget in a `Row`.
   - Avoid hardcoded rigid heights (e.g. `SizedBox(height: 140)`) with multiple `Spacer()` widgets when card children have multi-line dynamic content. Use `constraints: BoxConstraints(minHeight: ...)` with `mainAxisAlignment: MainAxisAlignment.spaceBetween` or explicit modest `SizedBox` gaps instead.
