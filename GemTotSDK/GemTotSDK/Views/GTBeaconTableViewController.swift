//
//  GTBeaconTableViewController.swift
//  GemTotSDK
//
//  Copyright (c) 2014 PassKit, Inc.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.


import UIKit

class GTBeaconTableViewController: UITableViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    // Constants - form elements
    let _toggleSwitch : UISwitch = UISwitch()
    let _dbPicker : UIPickerView = UIPickerView()
    let _numberToolbar : UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 50))

    // Shared objects
    let _iBeaconConfig : GTStorage = GTStorage.sharedGTStorage // Dictionary containing beacon config parameters
    let _beacon : GTBeaconBroadcaster = GTBeaconBroadcaster.sharedGTBeaconBroadcaster // Shared instance to allow continuous broadcasting after this view is dismissed
    
   
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false
        
        // Subscribe to notifications on toggle changes
        NotificationCenter.default.addObserver(self, selector: #selector(toggleStatus(_:)), name: NSNotification.Name(rawValue: "iBeaconBroadcastStatus"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        
        // Conifgure the toolbar and pickerview
        configureToolbarToggleAndPicker()
        
        // Add a gesture recognizer to make dismissing the keyboard easier
        addTapGestureRecognizers()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /**************************************************************************************
    *
    *  Helper Functions
    *
    **************************************************************************************/
    
    // Configures the view components ready for viewing
    func configureToolbarToggleAndPicker() {
        
        // Configure the toolbar that sits above the numeric keypad
        let toolbarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: NSLocalizedString("Done", comment: "Button to accept the iBeacon paramaters and dismiss the keyboard"), style: .plain, target: self, action: #selector(dismissKeyboard(_:)))
        ]
        
        _numberToolbar.setItems(toolbarButtonItems, animated:false)
        _numberToolbar.barStyle = .default
        _numberToolbar.isTranslucent = true
        _numberToolbar.sizeToFit()
        
        // Configure the date picker
        _dbPicker.dataSource = self;
        _dbPicker.delegate = self;
        _dbPicker.backgroundColor = .white
        
        // Configure the toggle
        _toggleSwitch.setOn(_beacon.beaconStatus(), animated: false)
        _toggleSwitch.addTarget(self, action: #selector(toggleBeacon(_:)), for: .valueChanged)
        
    }
    
    // Adds a tap gesture to the background to dismiss the keyboard if users click outside of the keyboard of input cells and a tap gesture to the table footer to copy the UUID to the clipboard
    func addTapGestureRecognizers() {
        
        let tapBackground : UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        self.view.addGestureRecognizer(tapBackground)
        
    }
    
    // Copy the UUID to the clipboard
    @objc private func copyUUID(_ sender: AnyObject) {
        let UUID = _iBeaconConfig.getValue(forKey: "UUID", fromStore:"iBeacon") as! String
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = UUID
        
        let alert = UIAlertController(title: NSLocalizedString("UUID copied clipboard", comment:"Alert UUID Copied to Clipboard"), message: nil, preferredStyle: .alert)
        alert.message = "\n" + UUID
        alert.addAction(UIAlertAction(title: NSLocalizedString("Okay", comment:"OK button used to dismiss alerts"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // callback funciton called whenever the toggle changes state
    @objc private func toggleBeacon(_ sender :AnyObject!) {
        
        let button = sender as! UISwitch
        let state = button.isOn

        if (state == true) {
            let beaconStarted = _beacon.startBeacon()
            if (beaconStarted.success == false) {
                _toggleSwitch.setOn(false, animated: false)
                let alert = UIAlertController(title: NSLocalizedString("Error Starting Beacon", comment:"Alert title for problemn starting beacon"), message: nil, preferredStyle: .alert)
                alert.message = beaconStarted.error as String?
                alert.addAction(UIAlertAction(title: NSLocalizedString("Okay", comment:"OK button used to dismiss alerts"), style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        
        } else {
            _beacon.stopBeacon()
        }
        
        // Reload the table to update the table footer message
        self.tableView.reloadData()
    }
    
    
    @objc private func toggleStatus(_ notification: NSNotification) {
        
        let packageContents = notification.userInfo! as NSDictionary
        
        _toggleSwitch.setOn(packageContents.object(forKey: "broadcastStatus") as! Bool, animated: false)
        
        if (packageContents.object(forKey: "broadcastStatus") as! Bool) {
            
            if (!_beacon.beaconStatus()) {
                _beacon.startBeacon()
            }
        }

        self.tableView.reloadData()
    }
    
    // Utility function to construct the footer message containin the advertising paramaters
    func footerString() -> String {
        
        let UUID = _iBeaconConfig.getValue(forKey: "UUID", fromStore:"iBeacon") as! String
        
        // Hack to ensure toggle is correctly set on first startup
        _toggleSwitch.setOn(_beacon.beaconStatus(), animated: false)
        
        // If the device is broadcasting, construct a string containing the advertising paramaters
        if (_beacon.beaconStatus() == true) {
            
            // retrieve the current values from the config dictionary
            let major = _iBeaconConfig.getValue(forKey: "major", fromStore:"iBeacon") as! NSNumber
            let minor = _iBeaconConfig.getValue(forKey: "minor", fromStore:"iBeacon") as! NSNumber
            let power = _iBeaconConfig.getValue(forKey: "power", fromStore: "iBeacon") as! NSNumber
            
            // Construct a readable string from the power value
            var powerString : String
            
            if (power.intValue == 127) {
                
                powerString = NSLocalizedString("Device Default", comment:"Label shown in table cell to indicate deivce will broadcast the default measured power")
                
            } else {
                let sign = (power.intValue <= 0  ? "" : "+")
                powerString = "\(sign)\(power)dB"
            }
            
            // Put it all together
            let footerString = String.localizedStringWithFormat(NSLocalizedString("Broadcasting beacon signal\n\nUUID: %@\nMajor: %@; Minor: %@\nMeasured Power: %@", comment:"Structured message to display the paramaters of the beacon signal that is currently being broadcast"), UUID, major, minor, powerString)
            
            return footerString
            
        } else {
            
            let footerString = String.localizedStringWithFormat(NSLocalizedString("UUID: %@\n\nThis device is not broadcasting a beacon signal", comment:"Text at bottom of iBeacon view when not broadcasting an iBeacon signal"), UUID)
            
            return footerString
        }
        
    }

    @objc private func dismissKeyboard(_ sender: AnyObject) {
        self.view.endEditing(true)
    }
    
    // Reloads the table to update the footer message whenever the keyboard is dismissed
    @objc private func onKeyboardHide(_ notification: NSNotification!) {
        self.tableView.reloadData()
    }
    
    // Function to check if string is a UUID, or to generate a constant UUID from a string
    func UUIDforString(_ UUIDNameOrString: String) -> String {
        
        // Test if UUIDNameOrString is a valid UUID, and if so, set the return it
        let range = UUIDNameOrString.range(of: "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}$", options: .regularExpression)

        if (range != nil && UUIDNameOrString.count == 36) {
            
          return UUIDNameOrString
            
        } else {
            
            //var ccount: UInt16 = 16 + UUIDNameOrString.characters.count.value as UInt16
            
            // Variable to hold the hashed namespace
            let hashString = NSMutableData()
            
            // Unique seed namespace - keep to generate UUIDs compatible with PassKit, or change to avoid conflicts
            // Needs to be a hexadecimal value - ideally a UUID
            let nameSpace: String = "b8672a1f84f54e7c97bdff3e9cea6d7a"
            
            // Convert each byte of the seed namespace to a character value and append the character byte
            let u16 = nameSpace.utf16
            var i = u16.startIndex
            while i != u16.endIndex {
                let high = u16[i] << 8
                let j = u16.index(after: i)
                let low: Unicode.UTF16.CodeUnit
                if j == u16.endIndex { low = 0 ; i = j }
                else { low = u16[j] ; i = u16.index(after: j) }
                var charValue = high ^ low
                hashString.append(&charValue, length: MemoryLayout.size(ofValue: charValue))
            }

            // Append the UUID String bytes to the hash input
            let uuidString = UUIDNameOrString.data(using: .utf8)!
            hashString.append(uuidString)

            // SHA1 hash the input
            let rawUUIDString = String(hashString.sha1())
            
            // Build the UUID string as defined in RFC 4122
            let si = rawUUIDString.startIndex
            let part3 = UInt32(rawUUIDString[rawUUIDString.index(si, offsetBy: 12)..<rawUUIDString.index(si, offsetBy: 16)], radix: 16) ?? 0
            let part4 = UInt32(rawUUIDString[rawUUIDString.index(si, offsetBy: 16)..<rawUUIDString.index(si, offsetBy: 20)], radix: 16) ?? 0
            let uuidPart1 = String(rawUUIDString[si..<rawUUIDString.index(si, offsetBy: 8)])
            let uuidPart2 = String(rawUUIDString[rawUUIDString.index(si, offsetBy: 8)..<rawUUIDString.index(si, offsetBy: 12)])
            let uuidPart3 = String(format:"%2X", (part3 & 0x0FFF) | 0x5000).lowercased()
            let uuidPart4 = String(format:"%2X", (part4 & 0x3FFF) | 0x8000).lowercased()
            let uuidPart5 = String(rawUUIDString[rawUUIDString.index(si, offsetBy: 20)..<rawUUIDString.index(si, offsetBy: 32)])

            return uuidPart1 + "-" + uuidPart2 + "-" +
                   uuidPart3 + "-" + uuidPart4 + "-" +
                   uuidPart5
        }
    }
    
    
    
    /**************************************************************************************
    *
    *  UITable View Delegate Functions
    *
    **************************************************************************************/

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        if (section == 0) {
            return 1
        } else {
            return 4
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.isUserInteractionEnabled = false
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.section == 0) {
        
            let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "iBeaconToggle")
        
            // Add the image to the table cell
            let cellImage = UIImage(named:"iBeaconTableCell")
            cell.imageView?.image = cellImage

            // Set the cell label
            cell.textLabel?.text = NSLocalizedString("Broadcast Signal", comment:"Label of iBeacon Toggle to start or stop broadcasting as an iBeacon") as String
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0)

            // Add the toggle to the table cell and
            let accessoryView = UIView(frame: _toggleSwitch.frame)
            cell.accessoryView = accessoryView
            accessoryView.addSubview(_toggleSwitch)

            // Make the cell non-selectable (only the toggle will be active)
            cell.selectionStyle = .none

            return cell

        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "iBeaconCell")

            let iBeaconParamsLabels = [
                NSLocalizedString("Name or UUID", comment:"Tabel cell label for beacon name or UUID value"),
                NSLocalizedString("Major Value", comment:"Table cell label for beacon major value"),
                NSLocalizedString("Minor Value", comment:"Table cell label for beacon minor value"),
                NSLocalizedString("Measured Power", comment:"Table cell label for beacon measured power value")
            ]
            
            // Set the cell label
            cell.textLabel?.text = iBeaconParamsLabels[indexPath.row]
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0)

            // Create and add a text field to the cell that will contain the value
            let optionalMargin: CGFloat = 10.0
            let valueField = UITextField(frame: CGRect(x: 170, y: 10, width: cell.contentView.frame.size.width - 170 - optionalMargin, height: cell.contentView.frame.size.height - 10 - optionalMargin))
            valueField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            valueField.delegate = self
            valueField.returnKeyType = .done
            valueField.clearButtonMode = .whileEditing
            valueField.font = UIFont.systemFont(ofSize: 16.0)
            cell.contentView.addSubview(valueField)
            
            switch (indexPath.row) {
                
            // Populate the value for each cell and configure the field UI as apporpriate for each value type
            case 0:
                valueField.text = _iBeaconConfig.getValue(forKey: "beaconName", fromStore: "iBeacon") as? String
                valueField.placeholder = NSLocalizedString("Name or UUID", comment:"Placehoder text for iBeacon name field")
                valueField.tag = 1
            
            case 1:
                valueField.text = (_iBeaconConfig.getValue(forKey: "major", fromStore: "iBeacon") as! NSNumber).stringValue
                valueField.placeholder = NSLocalizedString("0 - 65,535", comment:"iBeacon Major and Minor placehoder (represents min and max values)")
                valueField.keyboardType = .numberPad
                valueField.inputAccessoryView = _numberToolbar
                valueField.tag = 2
                
            case 2:
                valueField.text = (_iBeaconConfig.getValue(forKey: "minor", fromStore: "iBeacon") as! NSNumber).stringValue
                valueField.placeholder = NSLocalizedString("0 - 65,535", comment:"iBeacon Major and Minor placehoder (represents min and max values)")
                valueField.keyboardType = .numberPad
                valueField.inputAccessoryView = _numberToolbar
                valueField.tag = 3

            case 3:
                let powerValue = _iBeaconConfig.getValue(forKey: "power", fromStore: "iBeacon") as! Int
            
                if (powerValue == 127) {
                    valueField.text = NSLocalizedString("Device Default", comment:"Label shown in table cell to indicate deivce will broadcast the default measured power")
                } else {
                    let sign = (powerValue <= 0  ? "" : "+")
                    valueField.text = "\(sign)\(powerValue)dB"
                }
                valueField.tag = 4
                valueField.inputView = _dbPicker
                valueField.inputAccessoryView = _numberToolbar
                valueField.clearButtonMode = .never
                valueField.tintColor = .clear// This will hide the flashing cursor
            default:
                break
            }
            return cell
        }
    }

    //Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    //Override to support custom section headers.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return NSLocalizedString("Beacon Status", comment: "Header of first section of iBeacon view")
        } else if (section == 1) {
            return NSLocalizedString("Beacon Paramaers", comment: "Header of second section of iBeacon view")
        }
        
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if (section == 1) {
            
            let label: UILabel = UILabel()
            label.isUserInteractionEnabled = true
            label.text = footerString()
            label.baselineAdjustment = .alignBaselines;

            label.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
            label.textColor = .gray
            label.numberOfLines = 0
            label.sizeToFit()
            
            var frame: CGRect = label.frame
            let view: UIView = UIView()
            view.frame = frame
            
            // Add padding to align label to Table View
            frame.origin.x = 15;
            frame.origin.y = 5;
            frame.size.width = self.view.bounds.size.width - frame.origin.x;
            frame.size.height = frame.size.height + frame.origin.y;
            label.frame = frame;
            
            view.addSubview(label)
            view.sizeToFit()

            // Add a Gesture Recognizer to copy the UUID to the Clipboard
            let tapTableFooter : UITapGestureRecognizer = UITapGestureRecognizer (target: self, action: #selector(copyUUID(_:)))
            tapTableFooter.numberOfTapsRequired = 1
            label.addGestureRecognizer(tapTableFooter)

            return view
        }
        
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if (section == 1) {
            return 100;
        }
        
        return 0;
    }
    
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }


    /**************************************************************************************
    *
    *  UIPickerView Data Source and Delegate Functions
    *
    **************************************************************************************/
    
    func pickerView(_: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {

        if (row == 0) {
            // Set the first row of the picker view as an option to select the device default measured power
            return NSLocalizedString("Use Device Default Value", comment:"Description for selecting the device default power, shown on the pickser wheel.  Should be kept concise")

        } else {
            // Construct the a string to return.  Negative values will already be prexied with a minus sign
            let sign = (row < 102 ? "" : "+")
            return "\(sign)\(row - 101)dB"
        }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        // -100dB to +100dB inclusive plus an option to select device default measured power
        return 202
    }
    
    /**************************************************************************************
    *
    *  UITextField Delegate Functions
    *
    **************************************************************************************/
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // Dismiss the keyboard
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        
        switch (textField.tag) {
            
        case 1:
            // Replace empty string with a default value
            if (textField.text == "") {
                textField.text = "GemTot iOS"
            }

        case 2...3:
            
            // Validate the major and minor values before accepting.  If invalid, throw an alert and empty the field
            if (Int(textField.text!) ?? 0 > 0xFFFF) {
                let alert = UIAlertController(title: NSLocalizedString("Invalid Value", comment:"Alert title for invalid values"), message: nil, preferredStyle: .alert)
                alert.message = NSLocalizedString("Major and Minor keys can only accept a value between 0 and 65,535", comment:"Alert message to show if user enters an invalid Major or Minor value")
                alert.addAction(UIAlertAction(title: NSLocalizedString("Okay", comment:"OK button used to dismiss alerts"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
                textField.text = ""
            
                return false
            }
            
            // If an empty filed is submitted, replace with a 0 value
            if (textField.text == "") {
                textField.text = "0"
                return true
            }
            
        case 4:
            // Check if the picker view value is different to the field value and if so, update the field value and the config dictionary
            let row = _dbPicker.selectedRow(inComponent: 0)
            
            var targetText = ""
            
            if (row == 0) {
                targetText = NSLocalizedString("Device Default", comment:"Label shown in table cell to indicate deivce will broadcast the default measured power")
            } else {
                targetText = self.pickerView(_dbPicker, titleForRow: row, forComponent: 0)!
            }
            
            if (textField.text != targetText) {
                
                textField.text = targetText
                let dBValue = NSNumber(integerLiteral: row == 0 ? 127 : row - 101)
                _iBeaconConfig.write(value: dBValue, forKey: "power", toStore: "iBeacon")
            }
        default:
            
            return true
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        // Store the updated values in the config dictionary
        switch (textField.tag) {
            
        case 1:
            _iBeaconConfig.write(value: textField.text as NSString?, forKey:"beaconName", toStore:"iBeacon")
            _iBeaconConfig.write(value: UUIDforString(textField.text!) as AnyObject, forKey:"UUID", toStore:"iBeacon")

        case 2:
            _iBeaconConfig.write(value: textField.text.flatMap(Int.init).map { NSNumber(integerLiteral: $0) }, forKey: "major", toStore: "iBeacon")
            
        case 3:
            _iBeaconConfig.write(value: textField.text.flatMap(Int.init).map { NSNumber(integerLiteral: $0) }, forKey: "minor", toStore: "iBeacon")
            
        default:
            break
        }
        
        // If the beacon is broadcasting - dispatch a job to restart the beacon which will pick up the new values
        if (_toggleSwitch.isOn) {
            DispatchQueue.main.async {
                self._beacon.startBeacon()
            }
        }

        // Dismiss the keyboard
        textField.resignFirstResponder()
    }

    @IBAction func openSourceCode(sender: AnyObject) {
        UIApplication.shared.openURL(URL(string: "http://github.com/gemtot")!)
    }

    @IBAction func buyBeacons(sender: AnyObject) {
        UIApplication.shared.openURL(URL(string: "http://gemtot.com/")!)
    }
}
