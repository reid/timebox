/*
    suretimer.pde - countup timer for conferences, etc.
    Copyright 2010 Reid Burke <me@reidburke.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

// From http://milesburton.com/index.php/HT1632_Arduino_%22Matrix_Display%22_Library_for_the_Sure_2416_and_0832
#include "MatrixDisplay.h"
#include "DisplayToolbox.h"

// From http://northackton.stdin.co.uk/blog/2010/07/arduino-rocket-launcher/
#include "font.h"

#include <string.h>
#include <stdlib.h>
#include <avr/sleep.h>
#include <Time.h>

#define setMaster(dispNum, CSPin) initDisplay(dispNum,CSPin,true)
#define setSlave(dispNum, CSPin) initDisplay(dispNum,CSPin,false)

#define STATE_TIMER 50
#define STATE_SPLASH 120
#define STATE_READY 70

#define SLEEP_PIN 2
#define SLEEP_DEBOUNCE_MS 1500 // wait this long before sleeping again

#define TOGGLE_PIN 13

uint8_t X_MAX = 0;
uint8_t Y_MAX = 0;

MatrixDisplay disp(1,11,10, false);
DisplayToolbox toolbox(&disp);

void setupDisplay() {
  disp.setMaster(0,4);
}

unsigned long startMillis = 0;
unsigned long sleepMillis = 0;
unsigned long toggleMillis = 0;
int timePeriod = 1000;
int pos = 0;
int refreshes = 0;
boolean inverse = false;
char state = STATE_SPLASH;

void setup() {
  // Fetch bounds
  X_MAX = disp.getDisplayCount() * (disp.getDisplayWidth()-1)+1;
  Y_MAX = disp.getDisplayHeight();
 
  startMillis = millis();
  
  pinMode(SLEEP_PIN, INPUT);
  pinMode(TOGGLE_PIN, INPUT);
  
  setupDisplay();
}

void wake () {
  state = STATE_SPLASH;
}

void sleep () {
  // Notify the user we're about to sleep.
  disp.clear();
  toolbox.setBrightness(0);
  drawString(0, 0, "bye", false);
  disp.syncDisplays();
  delay(100);
  // Turn off display LEDs.
  disp.clear();
  disp.syncDisplays();
  // Attach interrupt 0 (pin 2).
  attachInterrupt(0, wake, LOW);
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable(); // Remove lock.
  sleep_mode(); // Goodnight.
  // We resume here.
  sleep_disable(); // Set lock.
  detachInterrupt(0);
  //setupDisplay();
}

void cycleState () {
  if (state == STATE_TIMER + 1) {
    state = STATE_SPLASH;
  } else {
    state = STATE_TIMER;
  }
}

void interstital () {
  disp.clear();
}

void loop()
{
  unsigned long elapsedMillis = millis() - startMillis;
  
  if (digitalRead(SLEEP_PIN) == HIGH && (millis() - sleepMillis) > SLEEP_DEBOUNCE_MS) {
    delay(150);
    if (digitalRead(SLEEP_PIN) == HIGH) {
      sleepMillis = millis();      
      sleep();
    }
  }
  
  if (digitalRead(TOGGLE_PIN) == LOW) {
    // FIXME: long delay for simplicity
    // blocks this loop, but the clock still runs
    delay(1000); // hold for 1s to toggle
    if (digitalRead(TOGGLE_PIN) == LOW) {
      toggleMillis = millis();   
      interstital();
      cycleState();
    }
  }

  if (state == STATE_TIMER) {
    toolbox.setBrightness(16);
    disp.clear();
    state = STATE_TIMER + 1;
    timePeriod = 1000;
    elapsedMillis = 1100;
    setTime(0);
  }
  
  if (state == STATE_TIMER + 1) {
    if (elapsedMillis > timePeriod) {
        startMillis = millis();
        disp.clear();
        
        draw_colon(18);
        
        draw_digits(20, second());

        uint8_t minutes_x = 6;
        int minutes = (minute() + (60 * hour()));
        if (minutes > 99)
          minutes_x = 0; // space for extra glyph
        draw_digits(minutes_x, minutes);

        disp.syncDisplays();
    }
  }

  if (state == STATE_SPLASH) {
      disp.clear();
      pos = 32;
      timePeriod = 30;
      elapsedMillis = 1000;
      toolbox.setBrightness(16);
      state = STATE_SPLASH + 1;
  }
    
  if (state == STATE_SPLASH + 1) {
      if (elapsedMillis > timePeriod) {
        startMillis = millis();
        
        if (pos > -44) { // -44
        
          disp.clear();
          drawString(pos, 0, "YUICONF 2010", false);
          disp.syncDisplays();
 
        } else if (pos < -64) {
          disp.clear();        
          // after pausing for a bit on 2010
          state = STATE_READY;
        }
        
        pos -= 1;

      }
  }
  
  if (state == STATE_READY) {
    disp.clear();
    pos = 0;
    timePeriod = 500;
    elapsedMillis = 1100;
    toolbox.setBrightness(14);
    state = STATE_READY + 1;
  }
  
  if (state == STATE_READY + 1) {
    if (elapsedMillis > timePeriod) {
      startMillis = millis();
      
      if (pos == 0) {
        drawString(0, 0, "ready", false);
      } else if (pos == 1) {
        disp.clear();
        drawString(10, 0, "set", false);
      } else if (pos == 2) {
        disp.clear();
        toolbox.setBrightness(16);
        drawString(20, 0, "go", true);
      } else if (pos > 2) {
        state = STATE_TIMER;
      }
      
      pos++;
    
      disp.syncDisplays();
    }
  }  
  
}

void draw_colon (uint8_t x) {
  toolbox.setPixel(x, 2, 1, true);
  toolbox.setPixel(x, 4, 1, true);
}

void draw_digits (uint8_t x, int digits) { 
  char result[3] = "  ";
  itoa(digits, result, 10);
  if (digits < 10) {
    result[1] = result[0];
    result[0] = '0';
  }
  drawString(x, 0, result, false);
}

void fill_display () {
  for (int y = 0; y < Y_MAX; ++y) {
    for (int x = 0; x< X_MAX; ++x) {
      toolbox.setPixel(x, y, 1, true);
     }
   }
}

// Portions adapted from RocketLauncher.pde (see URL in headers)
// Draw a single character at the desired location
void drawChar(char x, char y, char c, boolean inverse)
{
  uint8_t dots;
  if ((c >= 'A' && c <= 'Z')||(c >= 'a' && c <= 'z')) 
  {
    c &= 0x1F;   // A-Z maps to 1-26
  } 
  else if (c >= '.' && c <= ':') 
  {
    c = (c - '.') + 25; //  + 27
  } 
  else if (c == ' ') 
  {
    c = 0; // space
  }

  for (char col=0; col< 5; col++) 
  {
    dots = pgm_read_byte_near(&myfont[c][col]);
    for (char row=0; row < 8; row++) 
    {
      // Check the limits of the display
      if(((x+col) >= 0) && ((x+col) < X_MAX) &&
         ((y+row) >= 0) && ((y+row) < Y_MAX))
      {
        if (dots & (64>>row))   	     // only 7 rows.
          toolbox.setPixel(x+col, y+row, (inverse) ? 0 : 1);//, true);
        else 
          toolbox.setPixel(x+col, y+row, (inverse) ? 1 : 0);//, true);
      }
    }
  }
}


// Write out an entire string (Null terminated)
void drawString(uint8_t x, uint8_t y, char* c, boolean inverse)
{
  if (inverse) fill_display();
  for (char i=0; i< strlen(c); i++) {
    drawChar(x, y, c[i], inverse);
    x+=6; // Width of each glyph
  }
}
