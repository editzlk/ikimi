import Foundation
import CoreBluetooth

enum PrinterError: LocalizedError {
    case bluetoothOff
    case notFound
    case noWriteChannel
    case badData
    case busy
    case timeout
    case lostConnection

    var errorDescription: String? {
        switch self {
        case .bluetoothOff:
            return "Bluetooth is off. Turn it on and allow Bluetooth for OmniStaq in iPhone Settings."
        case .notFound:
            return "Printer not found. Switch it on, keep it close and try again."
        case .noWriteChannel:
            return "Connected, but this printer has no channel to send data."
        case .badData:
            return "Bad print data."
        case .busy:
            return "Printer is busy. Try again in a moment."
        case .timeout:
            return "Printing took too long."
        case .lostConnection:
            return "Printer disconnected while printing."
        }
    }
}

// Finds the thermal printer, connects, and sends the ESC/POS bytes in small pieces.
final class PrinterManager: NSObject {

    // Part of the printer's Bluetooth name (PT210_C983 contains "PT210")
    private let nameHint = "PT210"
    private let savedKey = "omniPrinterID"

    // Services that thermal printers usually use. These are checked first.
    private let usualServices = [
        "FF00", "FFE0", "FFF0", "FFB0", "FF12", "18F0", "AE30", "FEE7",
        "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2",
        "49535343-FE7D-4AE5-8FA9-9FAFD205E455"
    ]

    private var central: CBCentralManager!
    private var printer: CBPeripheral?
    private var writeChannel: CBCharacteristic?
    private var writeType: CBCharacteristicWriteType = .withoutResponse

    // connecting
    private var connectDone: ((Result<String, Error>) -> Void)?
    private var connectTimer: DispatchWorkItem?
    private var waitingForPower = false
    private var servicesLeft = 0
    private var usualChannels: [CBCharacteristic] = []
    private var otherChannels: [CBCharacteristic] = []

    // printing
    private var printDone: ((Result<String, Error>) -> Void)?
    private var printTimer: DispatchWorkItem?
    private var job = Data()
    private var offset = 0

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    private var isReady: Bool {
        return printer?.state == .connected && writeChannel != nil
    }

    // MARK: Connect

    func connect(done: @escaping (Result<String, Error>) -> Void) {
        if connectDone != nil {
            done(.failure(PrinterError.busy))
            return
        }
        if isReady {
            done(.success("Connected: \(printer?.name ?? "printer")"))
            return
        }

        connectDone = done

        let timer = DispatchWorkItem { [weak self] in
            self?.connectTimedOut()
        }
        connectTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timer)

        switch central.state {
        case .poweredOn:
            startConnect()
        case .unknown, .resetting:
            waitingForPower = true   // continues in centralManagerDidUpdateState
        default:
            finishConnect(.failure(PrinterError.bluetoothOff))
        }
    }

    private func startConnect() {
        waitingForPower = false
        writeChannel = nil

        // Use the printer we connected to last time, if we know it
        if let text = UserDefaults.standard.string(forKey: savedKey),
           let id = UUID(uuidString: text),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            open(known)
        } else {
            central.scanForPeripherals(withServices: nil)
        }
    }

    private func open(_ peripheral: CBPeripheral) {
        printer = peripheral
        peripheral.delegate = self

        if peripheral.state == .connected {
            usualChannels = []
            otherChannels = []
            peripheral.discoverServices(nil)
        } else {
            central.connect(peripheral)
        }
    }

    private func connectTimedOut() {
        central.stopScan()
        if let p = printer, p.state != .connected {
            central.cancelPeripheralConnection(p)
        }
        // Forget the saved printer so the next try scans again
        UserDefaults.standard.removeObject(forKey: savedKey)
        finishConnect(.failure(PrinterError.notFound))
    }

    private func finishConnect(_ result: Result<String, Error>) {
        connectTimer?.cancel()
        connectTimer = nil
        waitingForPower = false
        central.stopScan()

        let done = connectDone
        connectDone = nil
        done?(result)
    }

    private func pickChannel(of peripheral: CBPeripheral) {
        guard let channel = usualChannels.first ?? otherChannels.first else {
            finishConnect(.failure(PrinterError.noWriteChannel))
            return
        }

        writeChannel = channel
        if channel.properties.contains(.writeWithoutResponse) {
            writeType = .withoutResponse
        } else {
            writeType = .withResponse
        }

        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: savedKey)
        finishConnect(.success("Connected: \(peripheral.name ?? "printer")"))
    }

    // MARK: Print

    func printData(_ data: Data, done: @escaping (Result<String, Error>) -> Void) {
        if printDone != nil {
            done(.failure(PrinterError.busy))
            return
        }

        if isReady {
            startJob(data, done)
            return
        }

        // The printer may have gone to sleep, so connect again first
        connect { [weak self] result in
            switch result {
            case .success:
                self?.startJob(data, done)
            case .failure(let error):
                done(.failure(error))
            }
        }
    }

    private func startJob(_ data: Data, _ done: @escaping (Result<String, Error>) -> Void) {
        job = data
        offset = 0
        printDone = done

        let timer = DispatchWorkItem { [weak self] in
            self?.finishPrint(.failure(PrinterError.timeout))
        }
        printTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timer)

        sendNext()
    }

    // Sends the bytes piece by piece. For "without response" writes iOS tells us
    // when it can take more (peripheralIsReady), so we stop and wait when it is full.
    private func sendNext() {
        guard printDone != nil, let p = printer, let channel = writeChannel else {
            return
        }

        while offset < job.count {
            if writeType == .withoutResponse && !p.canSendWriteWithoutResponse {
                return
            }

            let room = p.maximumWriteValueLength(for: writeType)
            let size = max(20, min(room, 180))
            let end = min(offset + size, job.count)

            p.writeValue(job.subdata(in: offset..<end), for: channel, type: writeType)
            offset = end

            if writeType == .withResponse {
                return   // continues in didWriteValueFor
            }
        }

        finishPrint(.success("Printed"))
    }

    private func finishPrint(_ result: Result<String, Error>) {
        printTimer?.cancel()
        printTimer = nil
        job = Data()
        offset = 0

        let done = printDone
        printDone = nil
        done?(result)
    }
}

// MARK: - Bluetooth state, scanning, connecting

extension PrinterManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if waitingForPower {
                startConnect()
            }
        } else if connectDone != nil {
            finishConnect(.failure(PrinterError.bluetoothOff))
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advertised ?? ""

        guard name.uppercased().contains(nameHint),
              peripheral.state == .disconnected else {
            return
        }

        central.stopScan()
        open(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        usualChannels = []
        otherChannels = []
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        finishConnect(.failure(error ?? PrinterError.notFound))
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        writeChannel = nil
        if printDone != nil {
            finishPrint(.failure(PrinterError.lostConnection))
        }
    }
}

// MARK: - Services, characteristics, writing

extension PrinterManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = peripheral.services ?? []

        if error != nil || services.isEmpty {
            finishConnect(.failure(error ?? PrinterError.noWriteChannel))
            return
        }

        servicesLeft = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        servicesLeft -= 1

        let isUsual = usualServices.contains(service.uuid.uuidString.uppercased())

        for c in service.characteristics ?? [] {
            let canWrite = c.properties.contains(.write)
                || c.properties.contains(.writeWithoutResponse)
            if canWrite {
                if isUsual {
                    usualChannels.append(c)
                } else {
                    otherChannels.append(c)
                }
            }
        }

        if servicesLeft == 0 {
            pickChannel(of: peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            finishPrint(.failure(error))
            return
        }
        sendNext()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        sendNext()
    }
}
