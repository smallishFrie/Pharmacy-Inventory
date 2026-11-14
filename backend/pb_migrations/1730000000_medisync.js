migrate((app) => {
  const medicines = new Collection({
    name: "medicines",
    type: "base",
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
    fields: [
      { name: "name", type: "text", required: true },
      { name: "dosage", type: "text", required: true },
      { name: "cabinet", type: "text", required: true },
      { name: "slot", type: "number", required: false },
      { name: "stock", type: "number", required: false },
      { name: "batch", type: "text", required: true },
      { name: "expiry", type: "text", required: true },
      { name: "is_lasa", type: "bool" },
      { name: "lasa_group", type: "text" },
      { name: "daily_burn", type: "number", required: false }
    ]
  });
  app.save(medicines);
}, (app) => {
  try {
    const col = app.findCollectionByNameOrId("medicines");
    app.delete(col);
  } catch (_) {}
});