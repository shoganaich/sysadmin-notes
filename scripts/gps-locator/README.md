# GPS Locator

Small Windows utility that reads the latest GPS coordinates from a log file on a remote computer and opens the location in Google Maps.

## Files

```text
gps-locator/
|-- gps-locator.bat
|-- gps-locator.ps1
`-- GPSLocator.html
```

- `gps-locator.bat` provides the interactive interface and checks whether the remote host responds to ping.
- `gps-locator.ps1` reads the GPS log, extracts the coordinates, and generates the Google Maps URL.
- `GPSLocator.html` is generated automatically and redirects the default browser to the retrieved location.

## Dependency

This utility does not communicate directly with the GPS receiver.

It depends on an external GPS application that writes NMEA data to a log file, for example:

```text
C:\Logs\gps.log
```

The external GPS application is not included in this repository.

## How It Works

1. The batch file prompts for a remote hostname.
2. The host is checked using `ping`.
3. If the host is reachable, the PowerShell script accesses:

   ```text
   \\HOSTNAME\c$\Logs\gps.log
   ```

4. The script searches the last 10 log lines for a `$GPRMC` NMEA message.
5. The latitude and longitude are converted from the NMEA format to decimal degrees.
6. A temporary HTML file is created with a Google Maps redirect.
7. The HTML file is opened using the default Windows HTML handler.

## Requirements

- Windows PowerShell
- Network connectivity to the remote computer
- Permission to access the remote `C$` administrative share
- GPS log available at:

  ```text
  C:\Logs\gps.log
  ```

- Valid `$GPRMC` messages in the log
- Internet access for Google Maps

## Usage

Run:

```bat
gps-locator.bat
```

Enter the hostname when prompted:

```text
Host (ou Q para sair): COMPUTER-01
```

If valid GPS information is found, the script displays the converted coordinates and opens the location in Google Maps.

Enter `Q` to close the utility.

## Notes

- The batch and PowerShell files must remain in the same folder.
- `GPSLocator.html` is generated or overwritten after each successful lookup.
- The script only checks the last 10 lines of the GPS log.
- The remote host may respond to ping while still denying access to the administrative share.
- The browser used depends on the Windows `.html` file association.
- Latitude and longitude are formatted with a decimal point regardless of the Windows regional settings.

## Security

This utility accesses the `C$` administrative share and processes device location data.

Use it only on authorized systems and handle the retrieved coordinates according to the applicable security and privacy policies.
