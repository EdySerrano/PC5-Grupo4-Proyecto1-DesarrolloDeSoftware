import sys
import time
import urllib.request
import urllib.error
import json
import os

def verify_deployment(url, retries=5, delay=2):
    print(f"Verificando despliegue en {url}")
    
    for i in range(retries):
        try:
            with urllib.request.urlopen(url) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode())
                    if data.get("status") == "ok":
                        print(f"Verificacion de salud exitosa! Respuesta: {data}")
                        return True
                    else:
                        print(f"Estado inesperado en la verificacion: {data}")
                else:
                    print(f"La verificacion fallo con codigo de estado: {response.status}")
        except urllib.error.URLError as e:
            print(f"Intento {i+1}/{retries} fallido: {e}")
        
        if i < retries - 1:
            print(f"Reintentando en {delay} segundos")
            time.sleep(delay)
            
    print("La verificacion de salud fallo despues de todos los reintentos.")
    return False

if __name__ == "__main__":
    target_url = os.getenv("TARGET_URL", "http://localhost:8000/health")
    
    if len(sys.argv) > 1:
        target_url = sys.argv[1]
        
    success = verify_deployment(target_url)
    
    if not success:
        sys.exit(1)
    sys.exit(0)
