# GPS Locator

Small Windows utility that reads the latest GPS coordinates from a log file on a remote computer and opens the location in Google Maps.

The interface is in Portuguese because it was built for a Portuguese-speaking team.

## Files

```text
gps-locator/
|-- gps-locator.bat
|-- gps-locator.ps1
`-- GPSLocator.example.html
```

- `gps-locator.bat` provides the interactive interface and checks whether the remote host responds to ping.
- `gps-locator.ps1` reads the GPS log, extracts the coordinates, and generates the Google Maps URL.
- `GPSLocator.html` is generated automatically next to the script and redirects the default browser to the retrieved location. It is ignored by Git. `GPSLocator.example.html` shows what the generated file looks like.

## Dependency

This utility does not communicate directly with the GPS receiver.

It depends on an external GPS application that writes NMEA data to a log file at:

```text
C:\Path\To\gps.log
```

To use a different location, change the `$Log` line at the top of `gps-locator.ps1`.

The external GPS application is not included in this repository.

## How It Works

1. The batch file prompts for a remote hostname.
2. The host is checked using `ping`.
3. If the host is reachable, the PowerShell script accesses:

   ```text
   \\HOSTNAME\c$\Path\To\gps.log
   ```

4. The script searches the last 10 log lines for `$GPRMC` or `$GNRMC` NMEA messages and uses the most recent one.
5. It checks the RMC status field. If the receiver reports no fix (`V`), the script stops instead of showing a stale or invalid location.
6. The latitude and longitude are converted from the NMEA format to decimal degrees, and the time of the fix is shown.
7. A temporary HTML file is created with a Google Maps redirect.
8. The HTML file is opened using the default Windows HTML handler.

## Requirements

- Windows PowerShell
- Network connectivity to the remote computer
- Permission to access the remote `C$` administrative share
- GPS log available at:

  ```text
  C:\Path\To\gps.log
  ```

- Valid `$GPRMC` or `$GNRMC` messages in the log
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
- The script only checks the last 10 lines of the GPS log. Change `$TailLines` in the script if the log contains many other message types.
- Check the displayed fix time. If it is old, the receiver may have stopped updating the log.
- The remote host may respond to ping while still denying access to the administrative share.
- The browser used depends on the Windows `.html` file association.
- Latitude and longitude are formatted with a decimal point regardless of the Windows regional settings.

## Security

This utility accesses the `C$` administrative share and processes device location data.

Use it only on authorized systems and handle the retrieved coordinates according to the applicable security and privacy policies.
