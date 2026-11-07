import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';

Set<String> avatarPersonIds(List<Person> people, List<PersonPhoto> photos) {
  return {
    for (final person in people)
      if (avatarOf(photosOfPerson(photos, person.id)) != null) person.id,
  };
}
