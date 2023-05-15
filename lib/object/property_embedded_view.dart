import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:isar_inspector/object/isar_object.dart';
import 'package:isar_inspector/object/object_view.dart';
import 'package:isar_inspector/object/property_builder.dart';
import 'package:isar_inspector/object/property_value.dart';

class EmbeddedPropertyView extends StatelessWidget {
  const EmbeddedPropertyView({
    super.key,
    required this.property,
    required this.schemas,
    required this.object,
    required this.onUpdate,
  });

  final PropertySchema property;
  final Map<String, Schema<dynamic>> schemas;
  final IsarObject object;
  final void Function(int? id, String path, dynamic value) onUpdate;

  @override
  Widget build(BuildContext context) {
    if (property.type == IsarType.object) {
      final child = object.getNested(property.name);
      return PropertyBuilder(
        property: property.name,
        type: property.target!,
        value: child == null ? const NullValue() : null,
        children: [
          if (child != null)
            ObjectView(
              schemaName: property.target!,
              schemas: schemas,
              object: child,
              onUpdate: (_, id, path, value) {
                onUpdate(id, path, value);
              },
            ),
        ],
      );
    } else {
      final children = object.getNestedList(property.name);
      final childrenLength = children != null ? '(${children.length})' : '';
      return PropertyBuilder(
        property: property.name,
        type: 'List<${property.target}> $childrenLength',
        value: children == null ? const NullValue() : null,
        children: [
          for (var i = 0; i < (children?.length ?? 0); i++)
            PropertyBuilder(
              property: '$i',
              type: property.target!,
              value: children![i] == null ? const NullValue() : null,
              children: [
                if (children[i] != null)
                  ObjectView(
                    schemaName: property.target!,
                    schemas: schemas,
                    object: children[i]!,
                    onUpdate: (_, id, path, value) {
                      onUpdate(id, '$i.$path', value);
                    },
                  ),
              ],
            ),
        ],
      );
    }
  }
}
