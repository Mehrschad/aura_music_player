/// Pure helpers for multi-select logic, shared by [SelectionController] and
/// unit-tested in isolation.
library;

/// The inclusive set of ids lying between [anchorId] and [targetId] in
/// [orderedIds] (the list's current visual order). Direction-agnostic: the
/// anchor may sit before or after the target.
///
/// Falls back gracefully when an id isn't present: if the anchor is missing,
/// only [targetId] is returned; if the target is missing too, the result is
/// empty.
Set<String> idsInRange(
  List<String> orderedIds,
  String anchorId,
  String targetId,
) {
  final a = orderedIds.indexOf(anchorId);
  final b = orderedIds.indexOf(targetId);
  if (b < 0) return <String>{};
  if (a < 0) return <String>{targetId};
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return {for (var i = lo; i <= hi; i++) orderedIds[i]};
}
