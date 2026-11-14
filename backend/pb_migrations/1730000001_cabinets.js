migrate((app) => {
  const cabinets = new Collection({
    name: "cabinets",
    type: "base",
    listRule: "",
    viewRule: "",
    createRule: "",
    updateRule: "",
    deleteRule: "",
    fields: [
      { name: "name", type: "text", required: true },
      { name: "rows", type: "number", required: true },
      { name: "cols", type: "number", required: true }
    ]
  });
  app.save(cabinets);
}, (app) => {
  try {
    const col = app.findCollectionByNameOrId("cabinets");
    app.delete(col);
  } catch (_) {}
});