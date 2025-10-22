import 'package:flutter/material.dart';
import 'package:label_printer/models/brand.dart';

class HomePageManagerLogic {
  Future<List<Brand>> fetchBrands(int customerId) async {
    final rows = await BrandDAO.getByCustomerIdByBrandOrder(customerId) ?? <Brand>[];
    Brand.setBrands(rows);
    return rows;
  }

  List<DropdownMenuItem<String>> toDropdownItems(List<Brand> brands) => brands
    .map(
      (brand) => DropdownMenuItem<String>(
        value: brand.brandName,
        child: Text(brand.brandName, overflow: TextOverflow.ellipsis),
      ),
    )
    .toList();

  String? resolveSelectedBrand(List<Brand> brands, String selectedBrand) {
    for (final brand in brands) {
      if (brand.brandName == selectedBrand) {
        return brand.brandName;
      }
    }
    return null;
  }

  String? firstBrandName(List<Brand> brands) =>
    brands.isNotEmpty ? brands.first.brandName : null;
}
