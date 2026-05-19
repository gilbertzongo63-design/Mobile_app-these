import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO
from pathlib import Path

import requests
from PIL import Image


ROOT = Path(__file__).resolve().parent
ANNOTATIONS_PATH = ROOT / "TACO-master" / "TACO-master" / "data" / "annotations.json"
DATA_DIR = ANNOTATIONS_PATH.parent
MAX_WORKERS = 12
REQUEST_TIMEOUT = 45


def download_one(image_info):
    file_name = image_info["file_name"]
    file_path = DATA_DIR / file_name
    if file_path.exists():
        return "existing", file_name, None

    file_path.parent.mkdir(parents=True, exist_ok=True)
    urls = [image_info.get("flickr_640_url"), image_info.get("flickr_url")]
    last_error = None

    for url in urls:
        if not url:
            continue
        try:
            response = requests.get(url, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            image = Image.open(BytesIO(response.content))
            if image.mode not in ("RGB", "L"):
                image = image.convert("RGB")
            image.save(file_path)
            return "downloaded", file_name, None
        except Exception as exc:  # noqa: BLE001
            last_error = str(exc)

    return "failed", file_name, last_error


def main():
    with open(ANNOTATIONS_PATH, "r", encoding="utf-8") as file:
        annotations = json.load(file)

    images = annotations["images"]
    total = len(images)
    completed = 0
    downloaded = 0
    existing = 0
    failures = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(download_one, image): image for image in images}
        for future in as_completed(futures):
            status, file_name, error = future.result()
            completed += 1
            if status == "downloaded":
                downloaded += 1
            elif status == "existing":
                existing += 1
            else:
                failures.append({"file_name": file_name, "error": error})

            if completed % 25 == 0 or completed == total:
                print(
                    f"Progress: {completed}/{total} | "
                    f"downloaded={downloaded} existing={existing} failed={len(failures)}"
                )

    print(
        f"Finished. downloaded={downloaded} existing={existing} failed={len(failures)} total={total}"
    )
    if failures:
        failure_path = DATA_DIR / "download_failures.json"
        with open(failure_path, "w", encoding="utf-8") as file:
            json.dump(failures, file, indent=2, ensure_ascii=False)
        print(f"Failure log written to {failure_path}")


if __name__ == "__main__":
    main()
