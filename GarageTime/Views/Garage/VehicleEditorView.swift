import SwiftUI
import SwiftData

struct VehicleEditorView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm: VehicleEditorViewModel?
    let vehicle: Vehicle?
    let onDone: () -> Void

    @State private var showCustomerPicker: Bool = false
    @State private var showVINScanner: Bool = false
    @State private var showPhotoPicker: Bool = false

    var body: some View {
        Group {
            if let vm {
                form(vm: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if vm == nil {
                vm = VehicleEditorViewModel(backend: backend, context: context, vehicle: vehicle)
            }
        }
        .navigationTitle(vehicle == nil ? "New Vehicle" : "Edit Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                    onDone()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let vm {
                        let isNew = vm.editingVehicle == nil
                        _ = vm.save()
                        if isNew {
                            // Rate-limit bookkeeping for dealer-abuse prevention.
                            backend.quota.recordAdd(at: Date())
                        }
                        HapticsManager.success()
                        dismiss()
                        onDone()
                    }
                }
                .disabled(vm?.canSave != true)
                .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private func form(vm: VehicleEditorViewModel) -> some View {
        Form {
            // Owner section
            Section {
                Picker("Owner", selection: Binding(get: { vm.ownerType }, set: { vm.ownerType = $0 })) {
                    ForEach(OwnerType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                if vm.ownerType == .customer {
                    Button {
                        showCustomerPicker = true
                    } label: {
                        HStack {
                            Text(vm.selectedCustomer?.displayName ?? "Pick customer…")
                                .foregroundStyle(vm.selectedCustomer == nil ? Color.textTertiary : Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.textTertiary)
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
            } header: { Text("Owner") }

            // Identity section
            Section {
                GSTextField(title: "Nickname", text: Binding(get: { vm.name }, set: { vm.name = $0 }),
                            placeholder: "e.g. Daily Civic", icon: "tag.fill")

                // VIN with scan
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text("VIN")
                            .font(.wbCaption)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Button {
                            showVINScanner = true
                        } label: {
                            Label("Scan", systemImage: "viewfinder")
                                .font(.wbCaption)
                        }
                    }
                    GSTextField(
                        title: "",
                        text: Binding(get: { vm.vin }, set: { vm.vin = $0.uppercased() }),
                        placeholder: "17-character VIN",
                        icon: "number",
                        keyboard: .asciiCapable,
                        autocapitalization: .characters,
                        disableAutocorrection: true,
                        monospaced: true
                    )
                    if vm.isDecoding {
                        ProgressView("Decoding VIN…")
                            .font(.wbCaption)
                            .padding(.top, Spacing.xxs)
                    } else if let err = vm.decodeError {
                        Text(err)
                            .font(.wbCaptionSmall)
                            .foregroundStyle(Color.statusRed)
                    }
                    GSButton(title: "Decode VIN", icon: "wand.and.stars", style: .secondary, size: .small, fullWidth: false) {
                        Task { await vm.decodeVIN() }
                    }
                    .disabled(vm.vin.count < 17 || vm.isDecoding)
                }

                GSTextField(title: "License plate",
                            text: Binding(get: { vm.licensePlate }, set: { vm.licensePlate = $0.uppercased() }),
                            placeholder: "ABC-1234",
                            icon: "rectangle.righthalf.inset.filled.arrow.right",
                            autocapitalization: .characters)
            } header: { Text("Identity") }

            // Year/make/model
            Section {
                HStack(spacing: Spacing.s) {
                    GSNumberField(title: "Year",
                                  value: Binding(get: { Double(vm.year) }, set: { vm.year = Int($0) }),
                                  icon: "calendar",
                                  allowsDecimal: false,
                                  placeholder: "2024")
                    GSTextField(title: "Make", text: Binding(get: { vm.make }, set: { vm.make = $0 }), placeholder: "Honda")
                }
                HStack(spacing: Spacing.s) {
                    GSTextField(title: "Model", text: Binding(get: { vm.model }, set: { vm.model = $0 }), placeholder: "Civic")
                    GSTextField(title: "Trim",  text: Binding(get: { vm.trim }, set: { vm.trim = $0 }), placeholder: "Touring")
                }
            } header: { Text("Year / Make / Model") }

            // Classification
            Section {
                Picker("Type", selection: Binding(get: { vm.type }, set: { vm.type = $0 })) {
                    ForEach(VehicleType.allCases) { t in
                        Label(t.displayName, systemImage: t.sfSymbol).tag(t)
                    }
                }
                Picker("Powertrain", selection: Binding(get: { vm.powertrain }, set: { vm.powertrain = $0 })) {
                    ForEach(Powertrain.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            } header: { Text("Classification") }

            // Mileage
            Section {
                HStack(spacing: Spacing.s) {
                    GSNumberField(title: "Current mileage",
                                  value: Binding(get: { Double(vm.currentMileage) }, set: { vm.currentMileage = Int($0) }),
                                  icon: "speedometer",
                                  allowsDecimal: false)
                    Picker("Unit", selection: Binding(get: { vm.mileageUnit }, set: { vm.mileageUnit = $0 })) {
                        ForEach(MileageUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            } header: { Text("Mileage") }

            // Photo
            Section {
                HStack(spacing: Spacing.m) {
                    GSPhotoTile(imageData: vm.photoData, size: 88, placeholderIcon: "photo")
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PhotoPickerButton(imageData: Binding(get: { vm.photoData }, set: { vm.photoData = $0 })) {
                            Label("Choose photo", systemImage: "photo.on.rectangle.angled")
                                .font(.wbCaption)
                                .foregroundStyle(Color.accentPrimary)
                        }
                        if vm.photoData != nil {
                            Button(role: .destructive) {
                                vm.photoData = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.wbCaptionSmall)
                            }
                        }
                    }
                    Spacer()
                }
            } header: { Text("Photo") }

            // Purchase
            Section {
                DatePicker("Purchase date", selection: Binding(
                    get: { vm.purchaseDate ?? .now },
                    set: { vm.purchaseDate = $0 }
                ), displayedComponents: .date)

                GSNumberField(title: "Purchase price",
                              value: Binding(get: { vm.purchasePrice }, set: { vm.purchasePrice = $0 }),
                              icon: "dollarsign.circle")
            } header: { Text("Purchase") }

            // Customer-only: override labor rate
            if vm.ownerType == .customer {
                Section {
                    GSNumberField(
                        title: "Labor rate ($/hr) — override",
                        value: Binding(
                            get: { vm.laborRateOverride ?? 0 },
                            set: { vm.laborRateOverride = $0 == 0 ? nil : $0 }
                        ),
                        icon: "wrench.and.screwdriver.fill"
                    )
                    Text("Leave 0 to use the shop default.")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                } header: { Text("Billing") }
            }

            // Notes
            Section {
                GSTextEditor(title: "", text: Binding(get: { vm.notes }, set: { vm.notes = $0 }),
                             placeholder: "Tire size, oil weight, mod list, recent issues…")
            } header: { Text("Notes") }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .sheet(isPresented: $showCustomerPicker) {
            CustomerPickerSheet(selected: Binding(
                get: { vm.selectedCustomer },
                set: { vm.selectedCustomer = $0 }
            ))
        }
        .fullScreenCover(isPresented: $showVINScanner) {
            VisionScannerView(mode: .vin) { vinText in
                showVINScanner = false
                if !vinText.isEmpty {
                    vm.vin = vinText.uppercased()
                    Task { await vm.decodeVIN() }
                }
            } onCancel: {
                showVINScanner = false
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        VehicleEditorView(vehicle: nil) {}
    }
    .environment(Backend.preview())
    .modelContainer(PreviewModelContainer.shared)
}
