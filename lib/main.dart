import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MonApplication());
}

class MonApplication extends StatelessWidget {
  const MonApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnKaSugu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey[100],
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const PagePrincipale(),
    );
  }
}

// --- MODÈLE DE DONNÉES (Ajout de videoUrl) ---
class Produit {
  final String id;
  final String nom;
  final String prix;
  final String boutique;
  final String imageUrl;
  final String videoUrl; // NOUVEAU
  final String telephone;
  final String categorie;
  final String vendeurId;

  Produit(
    this.id,
    this.nom,
    this.prix,
    this.boutique,
    this.imageUrl,
    this.videoUrl,
    this.telephone,
    this.categorie,
    this.vendeurId,
  );
}

// --- PAGE PRINCIPALE ---
class PagePrincipale extends StatefulWidget {
  const PagePrincipale({super.key});

  @override
  State<PagePrincipale> createState() => _PagePrincipaleState();
}

class _PagePrincipaleState extends State<PagePrincipale> {
  int _indexActif = 0;

  final List<Widget> _pages = [
    const EcranRecherche(),
    const Scaffold(body: Center(child: Text("Page Catégories (Bientôt)"))),
    const Scaffold(body: Center(child: Text("Votre Panier est vide"))),
    const EcranProfil(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_indexActif],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexActif,
        onTap: (index) => setState(() => _indexActif = index),
        selectedItemColor: const Color(0xFFFF6D00),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Catégories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Panier',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// --- ÉCRAN DE RECHERCHE (Public) ---
class EcranRecherche extends StatefulWidget {
  const EcranRecherche({super.key});

  @override
  State<EcranRecherche> createState() => _EcranRechercheState();
}

class _EcranRechercheState extends State<EcranRecherche> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Produit> _tousLesProduits = [];
  List<Produit> _resultats = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'Tout',
    'Parfums',
    'Téléphones',
    'Vêtements',
    'Chaussures',
    'Autres',
  ];
  String _categorieSelectionnee = 'Tout';

  @override
  void initState() {
    super.initState();
    _chargerProduits();
  }

  void _chargerProduits() async {
    _firestore.collection('produits').snapshots().listen((snapshot) {
      setState(() {
        _tousLesProduits = snapshot.docs.map((doc) {
          final data = doc.data();
          return Produit(
            doc.id,
            data['nom'] ?? 'Sans nom',
            data['prix'] ?? '0 FCFA',
            data['boutique'] ?? 'Inconnue',
            data['imageUrl'] ?? '',
            data['videoUrl'] ?? '', // Récupération de la vidéo
            data['telephone'] ?? '',
            data['categorie'] ?? 'Autres',
            data['vendeurId'] ?? '',
          );
        }).toList();
        _rechercher();
        _isLoading = false;
      });
    });
  }

  void _rechercher() {
    setState(() {
      final texteTape = _controller.text.toLowerCase().trim();
      _resultats = _tousLesProduits.where((produit) {
        final correspondCategorie =
            _categorieSelectionnee == 'Tout' ||
            produit.categorie == _categorieSelectionnee;
        final nomProduit = produit.nom.toLowerCase();
        final nomBoutique = produit.boutique.toLowerCase();
        final correspondTexte =
            texteTape.isEmpty ||
            nomProduit.contains(texteTape) ||
            nomBoutique.contains(texteTape);
        return correspondCategorie && correspondTexte;
      }).toList();
    });
  }

  Future<void> _contacterVendeur(Produit produit) async {
    String numero = produit.telephone.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isNotEmpty && !numero.startsWith('223')) numero = '223$numero';
    final message = Uri.encodeComponent(
      "Bonjour, je suis intéressé par votre produit : ${produit.nom} à ${produit.prix} sur AnKaSugu.",
    );
    final url = Uri.parse("https://wa.me/$numero?text=$message");

    if (numero.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ce vendeur n'a pas renseigné de numéro."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir WhatsApp."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- AFFICHAGE DES DÉTAILS AVEC VIDÉO ---
  void _afficherDetails(Produit produit) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            produit.nom,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    produit.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 150),
                  ),
                ),
                const SizedBox(height: 15),

                // BOUTON VIDÉO SI DISPONIBLE
                if (produit.videoUrl.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(produit.videoUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Lien vidéo invalide"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.red,
                      size: 24,
                    ),
                    label: const Text(
                      "Voir la vidéo du produit",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                Text(
                  "Catégorie : ${produit.categorie}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  "Prix : ${produit.prix} FCFA",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFFFF6D00),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Boutique : ${produit.boutique}",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Fermer", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _contacterVendeur(produit);
              },
              icon: const Icon(Icons.chat, color: Colors.white, size: 18),
              label: const Text(
                "WhatsApp",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _construireCarteProduit(Produit produit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    produit.imageUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                // BADGE VIDÉO sur la miniature
                if (produit.videoUrl.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${produit.prix} FCFA",
                    style: const TextStyle(
                      color: Color(0xFFFF6D00),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.store, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        produit.boutique,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 18,
              ),
              onPressed: () => _afficherDetails(produit),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produitsALaUne = _tousLesProduits.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.storefront, size: 28),
            const SizedBox(width: 8),
            const Text(
              'AnKaSugu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: const Color(0xFFFF6D00),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Que cherchez-vous ?',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFFF6D00),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (value) => _rechercher(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6D00), Color(0xFFFF9800)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "Vendez vos produits\nsur AnKaSugu",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (produitsALaUne.isNotEmpty &&
                      _controller.text.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Text(
                        "À la une 🔥",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: produitsALaUne.length,
                        itemBuilder: (context, index) {
                          final produit = produitsALaUne[index];
                          return GestureDetector(
                            onTap: () => _afficherDetails(produit),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                        child: Image.network(
                                          produit.imageUrl,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    height: 120,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      if (produit.videoUrl.isNotEmpty)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          produit.nom,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${produit.prix} FCFA",
                                          style: const TextStyle(
                                            color: Color(0xFFFF6D00),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      "Catégories",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final estSelectionnee = _categorieSelectionnee == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cat),
                            selected: estSelectionnee,
                            onSelected: (bool selected) {
                              setState(() {
                                _categorieSelectionnee = cat;
                                _rechercher();
                              });
                            },
                            selectedColor: const Color(0xFFFF6D00),
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: estSelectionnee
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: estSelectionnee
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      "Tous les produits",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _resultats.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(child: Text("Aucun produit trouvé.")),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _resultats.length,
                            itemBuilder: (context, index) =>
                                _construireCarteProduit(_resultats[index]),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// --- ÉCRAN DE CONNEXION ---
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});
  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _soumettre() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty)
      return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erreur de connexion.";
      if (e.code == 'user-not-found') message = "Aucun compte trouvé.";
      if (e.code == 'wrong-password') message = "Mot de passe incorrect.";
      if (e.code == 'email-already-in-use') message = "Email déjà utilisé.";
      if (e.code == 'weak-password') message = "Mot de passe trop court.";
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6D00), Color(0xFFF5F7FA)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront,
                      size: 60,
                      color: Color(0xFFFF6D00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? "Espace Vendeur" : "Devenir Vendeur",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Color(0xFFFF6D00),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFFFF6D00),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _soumettre,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLogin ? "Se connecter" : "S'inscrire",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Pas de compte ? S'inscrire"
                          : "Déjà un compte ? Se connecter",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- ÉCRAN PROFIL (Gestion des produits du vendeur) ---
class EcranProfil extends StatelessWidget {
  const EcranProfil({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const EcranConnexion();
        }

        final user = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon Espace Vendeur'),
            backgroundColor: const Color(0xFFFF6D00),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              // EN-TÊTE DU PROFIL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6D00),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 40,
                        color: Color(0xFFFF6D00),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.email ?? "Vendeur AnKaSugu",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // BOUTON D'AJOUT
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EcranAjouterProduit(),
                    ),
                  ),
                  icon: const Icon(Icons.add_business, color: Colors.white),
                  label: const Text(
                    "Ajouter un nouveau produit",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                ),
              ),

              // LISTE DES PRODUITS DU VENDEUR
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Mes produits en vente",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('produits')
                      .where('vendeurId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6D00),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "Vous n'avez pas encore ajouté de produit.",
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                data['imageUrl'] ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image),
                              ),
                            ),
                            title: Text(data['nom'] ?? 'Sans nom'),
                            subtitle: Text("${data['prix']} FCFA"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                // Confirmation de suppression
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Supprimer le produit ?"),
                                    content: const Text(
                                      "Voulez-vous vraiment retirer ce produit de la vente ?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Annuler"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text(
                                          "Supprimer",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('produits')
                                      .doc(doc.id)
                                      .delete();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // BOUTON DE DÉCONNEXION
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Se déconnecter",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 55),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- ÉCRAN D'AJOUT DE PRODUIT (Avec champ Vidéo) ---
class EcranAjouterProduit extends StatefulWidget {
  const EcranAjouterProduit({super.key});

  @override
  State<EcranAjouterProduit> createState() => _EcranAjouterProduitState();
}

class _EcranAjouterProduitState extends State<EcranAjouterProduit> {
  final _nomController = TextEditingController();
  final _prixController = TextEditingController();
  final _boutiqueController = TextEditingController();
  final _imageController = TextEditingController();
  final _videoController = TextEditingController(); // NOUVEAU
  final _telephoneController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSaving = false;

  String _categorieSelectionnee = 'Parfums';
  final List<String> _categories = [
    'Parfums',
    'Téléphones',
    'Vêtements',
    'Chaussures',
    'Autres',
  ];

  void _sauvegarderProduit() async {
    if (_nomController.text.isEmpty || _prixController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le nom et le prix sont obligatoires."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await _firestore.collection('produits').add({
        'nom': _nomController.text,
        'prix': _prixController.text,
        'boutique': _boutiqueController.text.isEmpty
            ? "Boutique inconnue"
            : _boutiqueController.text,
        'imageUrl': _imageController.text.isEmpty
            ? "https://images.unsplash.com/photo-1541643600914-78b084683601?w=400&q=80"
            : _imageController.text,
        'videoUrl': _videoController.text, // NOUVEAU
        'telephone': _telephoneController.text,
        'categorie': _categorieSelectionnee,
        'vendeurId': user?.uid,
        'date': FieldValue.serverTimestamp(),
      });

      _nomController.clear();
      _prixController.clear();
      _boutiqueController.clear();
      _imageController.clear();
      _videoController.clear();
      _telephoneController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Produit mis en vente avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Produit'),
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Détails du produit",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // CHAMP IMAGE
            TextField(
              controller: _imageController,
              decoration: InputDecoration(
                labelText: "Lien de l'image (URL)",
                prefixIcon: const Icon(Icons.image, color: Color(0xFFFF6D00)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 15),

            // CHAMP VIDÉO (NOUVEAU)
            TextField(
              controller: _videoController,
              decoration: InputDecoration(
                labelText: "Lien de la vidéo (TikTok, YouTube...)",
                prefixIcon: const Icon(
                  Icons.video_camera_front,
                  color: Colors.red,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
                helperText:
                    "Optionnel. Collez le lien de la vidéo de votre produit.",
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _categorieSelectionnee,
              decoration: InputDecoration(
                labelText: "Catégorie",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(
                  Icons.category,
                  color: Color(0xFFFF6D00),
                ),
              ),
              items: _categories
                  .map(
                    (String cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat)),
                  )
                  .toList(),
              onChanged: (String? nouvelleValeur) =>
                  setState(() => _categorieSelectionnee = nouvelleValeur!),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nomController,
              decoration: InputDecoration(
                labelText: "Nom du produit *",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _prixController,
              decoration: InputDecoration(
                labelText: "Prix (ex: 10 000) *",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
                suffixText: "FCFA",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _boutiqueController,
              decoration: InputDecoration(
                labelText: "Nom de votre boutique",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.store, color: Color(0xFFFF6D00)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _telephoneController,
              decoration: InputDecoration(
                labelText: "Numéro WhatsApp (ex: 76 00 00 00)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF6D00)),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isSaving ? null : _sauvegarderProduit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Mettre en vente",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
