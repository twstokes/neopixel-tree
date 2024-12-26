#include <dos.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "trace.h"
#include "utils.h"
#include "packet.h"
#include "arp.h"
#include "udp.h"
#include "dns.h"


static void parseArgs( int argc, char *argv[] );
static void shutdown( int rc );


static char ServerAddrName[] = "tree.tannerstokes.com";
uint16_t treePort = 8733;

uint8_t command_length = 0;
uint8_t command_data[255];

// Check this flag once in a while to see if the user wants out.
volatile uint8_t CtrlBreakDetected = 0;

 void __interrupt __far ctrlBreakHandler( ) {
   CtrlBreakDetected = 1;
 }

 void __interrupt __far ctrlCHandler( ) {
   // Do Nothing - Ctrl-C is a legal character
 }


int main( int argc, char *argv[] ) {

  parseArgs( argc, argv );

  if ( Utils::parseEnv( ) != 0 ) {
    exit(-1);
  }

  if ( Utils::initStack( 0, 0, ctrlBreakHandler, ctrlCHandler ) ) {
    fprintf( stderr, "\nFailed to initialize TCP/IP - exiting\n" );
    exit(-1);
  }

  IpAddr_t ipAddr;
  int8_t rc = Dns::resolve( ServerAddrName, ipAddr, 1 );

  while ( 1 ) {
    if ( CtrlBreakDetected ) {
      break;
    }

    if ( biosIsKeyReady( ) ) {
      char c = biosKeyRead( );
      if ( (c == 27) || (c == 3) ) {
        break;
      }
    }

    PACKET_PROCESS_SINGLE;
    Arp::driveArp( );
    Dns::drivePendingQuery( );

    if ( !Dns::isQueryPending( ) ) {
      break;
    }
  }

  rc = Dns::resolve( ServerAddrName, ipAddr, 0 );
  if ( rc != 0 ) {
    printf( "Failed to resolve DNS.\n");
    shutdown ( -1 );
    return 0;
  }

  if ( command_length == 0 ) {
    printf( "Command length not set!\n" );
    shutdown ( -1 );
    return 0;
  }

  while( 1 ) {
    if ( CtrlBreakDetected ) {
      break;
    }

    if ( biosIsKeyReady( ) ) {
      char c = biosKeyRead( );
      if ( (c == 27) || (c == 3) ) {
        break;
      }
    }

    PACKET_PROCESS_SINGLE;
    Arp::driveArp( );
    rc = Udp::sendUdp( ipAddr, treePort, treePort, command_length, command_data, 0 );
    if ( rc < 1 ) {
      break;
    }
  }

  if ( rc == 0 ) {
    printf( "Command sent to tree!\n" );
  } else {
    printf( "There was a problem sending the packet. Return code: %d\n", rc );
  }

  shutdown( 0 );
}


static void shutdown( int rc ) {
  Utils::endStack( );
  Utils::dumpStats( stderr );
  exit( rc );
}

char *HelpText[] = {
  "\nxmastree <command> [options]\n\n",
  "Available commands:\n",
  "  brightness [0-255]           Set the tree's brightness\n",
  "  fill [0-255][0-255][0-255]   Fill all LEDs with a single RGB color\n",
  "  rainbow [0-1]                Show a rainbow sequence that can repeat\n",
  "  off                          Turn the tree off\n",
  "  help                         Show this help\n",
  NULL
};


void usage( void ) {
  uint8_t i=0;
  while ( HelpText[i] != NULL ) {
    fprintf( stderr, HelpText[i] );
    i++;
  }
  exit( 1 );
}

void parseArgs( int argc, char *argv[] ) {
  if ( argc < 2 ) {
    usage ( );
  }

  if ( stricmp( argv[1], "help" ) == 0 ) {
    usage( );
  }
  else if ( stricmp( argv[1], "brightness" ) == 0 ) {
    if ( argc != 3 ) {
      usage ( );
    }
    command_length = 2;
    command_data[0] = 1;
    command_data[1] = atoi( argv[2] );
  }
  else if ( stricmp( argv[1], "fill" ) == 0 ) {
    if ( argc != 5 ) {
      usage ( );
    }
    command_length = 4;
    command_data[0] = 3;
    command_data[1] = atoi( argv[2] );
    command_data[2] = atoi( argv[3] );
    command_data[3] = atoi( argv[4] );
  }
  else if ( stricmp( argv[1], "rainbow" ) == 0 ) {
    if ( argc != 3 ) {
      usage ( );
    }
    command_length = 2;
    command_data[0] = 5;
    command_data[1] = atoi( argv[2] );
  }
  else if ( stricmp( argv[1], "off" ) == 0 ) {
    if ( argc != 2 ) {
      usage ( );
    }
    command_length = 1;
    command_data[0] = 0;
  }
  else {
    fprintf( stderr, "Unknown option %s\n", argv[1] );
    usage( );
  }

}
