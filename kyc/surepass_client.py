import requests
from django.conf import settings


class SurepassError(Exception):
    def __init__(self, message: str, status_code: int | None = None, payload: dict | None = None, raw_text: str | None = None):
        super().__init__(message)
        self.status_code = status_code
        self.payload = payload
        self.raw_text = raw_text



class SurepassClient:
    def __init__(self):
        self.base = settings.SUREPASS_BASE_URL.rstrip("/")
        self.token = settings.SUREPASS_TOKEN.strip()

    def _json_headers(self):
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def _auth_headers(self):
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def aadhaar_generate_otp(self, id_number: str) -> dict:
        url = f"{self.base}/aadhaar-v2/generate-otp"

        try:
            r = requests.post(
                url,
                json={"id_number": id_number},
                headers=self._json_headers(),
                timeout=20
            )
        except requests.RequestException as e:
            # network/timeout etc. (no HTTP status available)
            raise SurepassError(f"Surepass generate-otp request failed: {e}", status_code=None)

        # Try to parse JSON safely
        payload = None
        try:
            payload = r.json()
        except Exception:
            payload = None

        # Non-200 => raise with exact status code
        if r.status_code != 200:
            msg = None
            if isinstance(payload, dict):
                msg = payload.get("message") or payload.get("detail")
            msg = msg or f"Surepass generate-otp error {r.status_code}"
            raise SurepassError(msg, status_code=r.status_code, payload=payload if isinstance(payload, dict) else None, raw_text=r.text)

        # 200 but success=false => still error (treat as 400)
        if isinstance(payload, dict) and not payload.get("success", False):
            msg = payload.get("message") or f"Surepass generate-otp unsuccessful"
            raise SurepassError(msg, status_code=400, payload=payload, raw_text=r.text)

        return payload if isinstance(payload, dict) else {}


    def aadhaar_submit_otp(self, client_id: str, otp: str) -> dict:
        url = f"{self.base}/aadhaar-v2/submit-otp"
        try:
            r = requests.post(url, json={"client_id": client_id, "otp": otp}, headers=self._json_headers(), timeout=30)
        except requests.RequestException as e:
            raise SurepassError(f"Surepass submit-otp request failed: {e}")

        if r.status_code != 200:
            raise SurepassError(f"Surepass submit-otp error {r.status_code}: {r.text}")

        data = r.json()
        if not data.get("success", False):
            raise SurepassError(f"Surepass submit-otp unsuccessful: {data}")
        return data

    def face_liveness(self, selfie_bytes: bytes, filename: str) -> dict:
        url = f"{self.base}/face/face-liveness"
        files = {"file": (filename, selfie_bytes)}
        try:
            r = requests.post(url, files=files, headers=self._auth_headers(), timeout=30)
        except requests.RequestException as e:
            raise SurepassError(f"Surepass liveness request failed: {e}")

        if r.status_code != 200:
            raise SurepassError(f"Surepass liveness error {r.status_code}: {r.text}")

        data = r.json()
        if not data.get("success", False):
            raise SurepassError(f"Surepass liveness unsuccessful: {data}")
        return data

    def face_match(self, selfie_bytes: bytes, id_card_bytes: bytes, selfie_filename: str, id_filename: str = "id.jpg") -> dict:
        url = f"{self.base}/face/face-match"
        files = {
            "selfie": (selfie_filename, selfie_bytes),
            "id_card": (id_filename, id_card_bytes),
        }
        try:
            r = requests.post(url, files=files, headers=self._auth_headers(), timeout=40)
        except requests.RequestException as e:
            raise SurepassError(f"Surepass face-match request failed: {e}")

        if r.status_code != 200:
            raise SurepassError(f"Surepass face-match error {r.status_code}: {r.text}")

        data = r.json()
        if not data.get("success", False):
            raise SurepassError(f"Surepass face-match unsuccessful: {data}")
        return data

    def driving_license_verify(self, license_number: str, dob: str) -> dict:
        """
        Verify Driving License with Surepass API.
        
        Args:
            license_number: Driving license number
            dob: Date of birth in format "YYYY-MM-DD"
        
        Returns:
            dict: Response data from Surepass API
        """
        url = f"{self.base}/driving-license/driving-license"
        
        try:
            r = requests.post(
                url,
                json={"id_number": license_number, "dob": dob},
                headers=self._json_headers(),
                timeout=30
            )
        except requests.RequestException as e:
            raise SurepassError(f"Surepass driving-license request failed: {e}", status_code=None)

        # Try to parse JSON safely
        payload = None
        try:
            payload = r.json()
        except Exception:
            payload = None

        # Non-200 => raise with exact status code
        if r.status_code != 200:
            msg = None
            if isinstance(payload, dict):
                msg = payload.get("message") or payload.get("detail")
            msg = msg or f"Surepass driving-license error {r.status_code}"
            raise SurepassError(msg, status_code=r.status_code, payload=payload if isinstance(payload, dict) else None, raw_text=r.text)

        # 200 but success=false => still error (treat as 400)
        if isinstance(payload, dict) and not payload.get("success", False):
            msg = payload.get("message") or f"Surepass driving-license unsuccessful"
            raise SurepassError(msg, status_code=400, payload=payload, raw_text=r.text)

        return payload if isinstance(payload, dict) else {}
