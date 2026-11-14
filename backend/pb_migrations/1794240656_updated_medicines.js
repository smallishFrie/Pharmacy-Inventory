/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3967082532")

  // remove field
  collection.fields.removeById("number290718353")

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3967082532")

  // add field
  collection.fields.addAt(10, new Field({
    "help": "",
    "hidden": false,
    "id": "number290718353",
    "max": null,
    "min": null,
    "name": "daily_burn",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
})
