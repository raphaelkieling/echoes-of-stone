local Catalog = require("src.game.narratives.NarrativeCatalog")

Catalog.register("altar_discovery", {
    steps = {
        { type = "dialogue", speaker = "The old altar", text = "The stone hums beneath your hand." },
        { type = "wait",     duration = 0.35 },
        { type = "dialogue", speaker = "",              text = "Something here remembers the old world." },
    },
})


Catalog.register("tutorial_undo", {
    steps = {
        { type = "dialogue", speaker = "", text = "Seems that you can undo things pressing K" },
    },
})
