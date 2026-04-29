# Simple Flask app — the 'application' being containerised
from flask import Flask, jsonify
 
app = Flask(__name__)
 
@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'container-security-demo',
        'version': '1.0.0'
    })
 
@app.route('/')
def index():
    return jsonify({
        'message': 'Advanced Container Security Platform Demo',
        'pipeline': 'Trivy > Cosign > in-toto > SLSA > Rekor'
    })
 
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
