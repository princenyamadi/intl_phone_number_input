import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/src/models/country_model.dart';
import 'package:intl_phone_number_input/src/providers/country_provider.dart';
import 'package:intl_phone_number_input/src/widgets/countries_search_list_widget.dart';

/// Opens the searchable country selector as a modal bottom sheet and resolves
/// to the chosen [Country], or `null` if the sheet was dismissed.
///
/// This is the same picker [InternationalPhoneNumberInput] uses, exposed so a
/// custom phone field can present an identical selector without depending on
/// that widget's layout.
///
/// Pass either an explicit [countries] list or [isoCodes] to restrict the
/// options; omit both for every country.
///
/// ```dart
/// final country = await showCountryPickerSheet(context, isoCodes: ['GH', 'NG']);
/// if (country != null) setState(() => _country = country);
/// ```
Future<Country?> showCountryPickerSheet(
  BuildContext context, {
  List<Country>? countries,
  List<String>? isoCodes,
  String? locale,
  InputDecoration? searchBoxDecoration,
  bool autoFocusSearch = false,
  bool isScrollControlled = true,
  bool useSafeArea = false,
  bool showFlags = true,
  bool useEmoji = false,
}) {
  final List<Country> options =
      countries ?? CountryProvider.getCountriesData(countries: isoCodes);

  return showModalBottomSheet<Country>(
    context: context,
    clipBehavior: Clip.hardEdge,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    useSafeArea: useSafeArea,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    ),
    builder: (BuildContext sheetContext) {
      return Stack(
        children: [
          GestureDetector(onTap: () => Navigator.pop(sheetContext)),
          Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: DraggableScrollableSheet(
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Directionality(
                  textDirection: Directionality.of(sheetContext),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Theme.of(context).canvasColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                    ),
                    child: CountrySearchListWidget(
                      options,
                      locale,
                      searchBoxDecoration: searchBoxDecoration,
                      scrollController: scrollController,
                      showFlags: showFlags,
                      useEmoji: useEmoji,
                      autoFocus: autoFocusSearch,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
