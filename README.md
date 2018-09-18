eg:
```
class User < ApplicationRecord

  include Extendable
  store_json :store_json, accessors: {
    is_parent:   TrueClass,
    name:        String,
    inter_field: Integer
  }, prefix: false

end

@user = User.first

@user.name = "example_name"
@user.is_parent = 't' || 'f' || true || false || 'true'
@user.save

# i18n
User.store_jsons_i18n

# scope

User.with_name("xx")
User.with_is_parent
User.with_not_is_parent

```