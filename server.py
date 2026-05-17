from anki_connect_server.api import AnkiConnectRequest, AnkiConnectResponse, app, handle_request
from anki_connect_server import wrapper


def ensure_model_for_note(note: dict) -> None:
    anki = wrapper.get_anki_wrapper()
    if not anki:
        return

    model_name = note.get("modelName")
    if not model_name or model_name in anki.model_names():
        return

    fields = list(note.get("fields", {}).keys())
    if "Front" in fields and "Back" in fields:
        qfmt = "{{Front}}"
        afmt = "{{FrontSide}}<hr id=answer>{{Back}}"
    elif "Cloze" in fields:
        qfmt = "{{cloze:Cloze}}"
        afmt = "{{cloze:Cloze}}<br>{{Back Extra}}"
    else:
        qfmt = "{{" + fields[0] + "}}" if fields else ""
        afmt = "{{FrontSide}}"

    anki.create_model(
        model_name=model_name,
        in_order_fields=fields,
        card_templates=[
            {
                "Name": "Card 1",
                "Front": qfmt,
                "Back": afmt,
            }
        ],
        css=".card { font-family: arial; font-size: 20px; text-align: left; color: black; background-color: white; }",
        is_cloze="Cloze" in fields,
    )


async def handle_compat_request(req: AnkiConnectRequest):
    if req.action == "requestPermission":
        return {
            "result": {
                "permission": "granted",
                "requireApiKey": False,
                "version": 6,
            },
            "error": None,
        }

    if req.action == "getMediaFilesNames":
        return {"result": [], "error": None}

    if req.action == "addNote":
        ensure_model_for_note(req.params.get("note", {}))

    response = await handle_request(req)
    return response


@app.post("/", response_model=AnkiConnectResponse)
async def handle_root_request(req: AnkiConnectRequest):
    return await handle_compat_request(req)


@app.post("/api", response_model=AnkiConnectResponse)
async def handle_api_request(req: AnkiConnectRequest):
    return await handle_compat_request(req)
