// backend.cpp : Defines the entry point for the application.
//

#include "backend.h"

using namespace std;

int main()
{
	cout << "Starting Isles of Resistance Server..." << endl;

	WebSocketServer server;
	server.start(9000);  // Start WebSocket server

	RestApi api;
	api.start(8080);  // Start REST API server

	return 0;
}
