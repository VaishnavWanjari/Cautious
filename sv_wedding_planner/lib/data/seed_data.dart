import '../models/enums.dart';
import '../models/other_models.dart';
import '../models/wedding_profile.dart';

/// The demo configuration from the product brief — Vaishnav & Shefali's
/// Maharashtrian Hindu wedding. Used to showcase personalization end-to-end.
class SeedData {
  static WeddingProfile demoProfile() => WeddingProfile(
        coupleGroom: 'Vaishnav Wanjari',
        coupleBride: 'Shefali Verma',
        persona: Persona.groom,
        side: WeddingSide.groomSide,
        weddingDate: DateTime(2026, 11, 25),
        receptionDate: DateTime(2026, 11, 29),
        engagementDate: DateTime(2026, 9, 20),
        honeymoonDate: DateTime(2026, 12, 3),
        religion: 'Hindu',
        community: 'Maharashtrian',
        state: 'Maharashtra',
        budget: 3500000,
        guestCount: 350,
        receptionIncluded: true,
        honeymoonIncluded: true,
        destinationWedding: false,
        vegetarian: true,
        alcohol: false,
        venueBooked: false,
        photographerBooked: false,
        decoratorBooked: false,
        engagementDone: false,
        shoppingStarted: false,
      );

  static List<Vendor> demoVendors() => [
        Vendor(name: 'Frames Forever Studio', type: 'Photographer', phone: '+91 90000 10001', contractAmount: 300000, paidAmount: 100000, rating: 4.7, booked: true),
        Vendor(name: 'Annapurna Caterers', type: 'Caterer', phone: '+91 90000 10002', contractAmount: 500000, paidAmount: 150000, rating: 4.5, booked: true),
        Vendor(name: 'Bloom & Bloom Decor', type: 'Decorator', phone: '+91 90000 10003', contractAmount: 350000, rating: 4.3),
        Vendor(name: 'Pandit Sharma Ji', type: 'Priest', phone: '+91 90000 10004', contractAmount: 25000, rating: 4.9, booked: true),
      ];

  static List<BudgetItem> demoBudget() => [
        BudgetItem(category: 'Venue', planned: 900000, actual: 600000),
        BudgetItem(category: 'Catering', planned: 620000, actual: 150000),
        BudgetItem(category: 'Decoration', planned: 520000, actual: 90000),
        BudgetItem(category: 'Photography', planned: 340000, actual: 100000),
        BudgetItem(category: 'Clothing', planned: 470000, actual: 180000),
        BudgetItem(category: 'Jewellery', planned: 580000, actual: 0),
        BudgetItem(category: 'Makeup', planned: 155000, actual: 0),
        BudgetItem(category: 'Travel', planned: 300000, actual: 0),
        BudgetItem(category: 'Miscellaneous', planned: 200000, actual: 45000),
      ];

  static List<ShoppingItem> demoShopping() => [
        ShoppingItem(name: 'Groom Sherwani + Safa', forPerson: 'Groom', budget: 90000, store: 'Manyavar'),
        ShoppingItem(name: 'Bridal Lehenga', forPerson: 'Bride', budget: 180000, store: 'Sabyasachi'),
        ShoppingItem(name: 'Bridal Jewellery Set', forPerson: 'Bride', budget: 500000, store: 'Tanishq'),
        ShoppingItem(name: 'Mother of Groom Saree', forPerson: 'Parents', budget: 60000, store: 'Nalli'),
        ShoppingItem(name: 'Sangeet Outfits', forPerson: 'Siblings', budget: 45000, store: 'Local'),
      ];

  static List<Guest> demoGuests() => [
        Guest(name: 'Wanjari Family (Nagpur)', side: 'Groom', seats: 25, rsvp: 'Yes', invited: true),
        Guest(name: 'Verma Family (Pune)', side: 'Bride', seats: 30, rsvp: 'Yes', invited: true),
        Guest(name: 'College Friends', side: 'Groom', seats: 18, rsvp: 'Pending', invited: true),
        Guest(name: 'Office Colleagues', side: 'Bride', seats: 12, rsvp: 'Pending'),
      ];

  static const honeymoonDestinations = [
    ('Maldives', 'Overwater villas, ideal in December', 250000),
    ('Bali, Indonesia', 'Beaches, temples, visa-on-arrival', 180000),
    ('Switzerland', 'Alpine winter romance', 420000),
    ('Andaman Islands', 'No passport needed, pristine beaches', 120000),
    ('Thailand', 'Budget-friendly, easy visa', 140000),
    ('Santorini, Greece', 'Iconic sunsets and caldera views', 380000),
  ];
}
